#!/usr/bin/env python3
"""
Tohray CLI Client - Post to your tohray blog from the command line
"""
import argparse
import os
import re
import sys
import time
from getpass import getpass
from pathlib import Path

try:
    import requests
except ImportError:
    print("Error: requests library not found. Install with: pip install requests")
    sys.exit(1)

# Try to import TOML library (tomllib in Python 3.11+, tomli for older versions)
try:
    import tomllib
except ImportError:
    try:
        import tomli as tomllib
    except ImportError:
        tomllib = None


class TohrayClient:
    def __init__(self, base_url, username, password):
        self.base_url = base_url.rstrip('/')
        self.username = username
        self.password = password
        self.session = requests.Session()

    def extract_csrf_token(self, html):
        """Extract CSRF token from HTML"""
        match = re.search(r'name="CSRFToken"\s+value="([^"]+)"', html)
        if match:
            return match.group(1)
        return None

    def login(self):
        """Login to get session cookie"""
        # Get login page to extract CSRF token
        resp = self.session.get(f"{self.base_url}/login")
        if resp.status_code != 200:
            raise Exception(f"Failed to load login page: {resp.status_code}")

        csrf_token = self.extract_csrf_token(resp.text)
        if not csrf_token:
            raise Exception("Could not find CSRF token on login page")

        # Submit login form
        login_data = {
            'username': self.username,
            'password': self.password,
            'CSRFToken': csrf_token
        }

        resp = self.session.post(f"{self.base_url}/login", data=login_data)
        if resp.status_code not in [200, 302]:
            raise Exception(f"Login failed: {resp.status_code}")

        # Check if login was successful by looking for redirect or session
        if 'Incorrect' in resp.text:
            raise Exception("Login failed: Incorrect username or password")

        return True

    def create_post(self, content, slug=None):
        """Create a new post"""
        # Get write page to extract CSRF token
        resp = self.session.get(f"{self.base_url}/write")
        if resp.status_code == 302:
            raise Exception("Not authenticated. Login failed.")
        if resp.status_code != 200:
            raise Exception(f"Failed to load write page: {resp.status_code}")

        csrf_token = self.extract_csrf_token(resp.text)
        if not csrf_token:
            raise Exception("Could not find CSRF token on write page")

        # If no slug provided, use epoch timestamp
        if not slug:
            slug = str(int(time.time()))

        # Submit post
        post_data = {
            'content': content,
            'slug': slug,
            'CSRFToken': csrf_token
        }

        resp = self.session.post(f"{self.base_url}/write", data=post_data)
        if resp.status_code not in [200, 302]:
            raise Exception(f"Failed to create post: {resp.status_code}")

        return slug


def load_config(config_path):
    """Load configuration from TOML file"""
    if tomllib is None:
        print("Error: TOML library not found. Install with: pip install tomli")
        sys.exit(1)

    try:
        with open(config_path, 'rb') as f:
            config = tomllib.load(f)
            return config
    except FileNotFoundError:
        print(f"Error: Config file not found: {config_path}")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading config file: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description='Post to your tohray blog from the command line',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Post with auto-generated slug (using client.toml)
  %(prog)s "This is my blog post content"

  # Post with custom slug
  %(prog)s "My thoughts today" --slug "thoughts-2024"

  # Use specific config file
  %(prog)s "Quick post" --config ~/my-config.toml

  # Read content from file
  %(prog)s "$(cat mypost.md)" --slug "my-post"

Configuration priority (highest to lowest):
  1. Command-line arguments (--url, --username, --password)
  2. Config file (--config or client.toml in current directory)
  3. Environment variables (TOHRAY_URL, TOHRAY_USER, TOHRAY_PASS)
  4. Interactive prompt
        """
    )

    parser.add_argument('content', help='Post content (markdown supported)')
    parser.add_argument('--slug', help='Post slug (optional, defaults to epoch timestamp)')
    parser.add_argument('--config', help='Path to config file (default: client.toml)')
    parser.add_argument('--url', help='Tohray instance URL')
    parser.add_argument('--username', help='Username')
    parser.add_argument('--password', help='Password')

    args = parser.parse_args()

    # Load config from TOML file if it exists
    config = {}
    config_path = args.config or 'client.toml'
    if os.path.exists(config_path):
        config = load_config(config_path)

    # Get configuration with priority: CLI args > TOML config > env vars > default
    base_url = (
        args.url or
        config.get('url') or
        os.getenv('TOHRAY_URL', 'http://localhost:8080')
    )
    username = (
        args.username or
        config.get('username') or
        os.getenv('TOHRAY_USER')
    )
    password = (
        args.password or
        config.get('password') or
        os.getenv('TOHRAY_PASS')
    )

    # Prompt for missing credentials
    if not username:
        username = input('Username: ')
    if not password:
        password = getpass('Password: ')

    if not username or not password:
        print("Error: Username and password are required")
        sys.exit(1)

    try:
        # Create client and login
        client = TohrayClient(base_url, username, password)
        print(f"Logging in to {base_url}...")
        client.login()
        print("✓ Logged in successfully")

        # Create post
        print("Creating post...")
        slug = client.create_post(args.content, args.slug)
        print(f"✓ Post created successfully!")
        print(f"  URL: {base_url}/{slug}")

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
