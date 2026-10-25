import os
import requests
import json
import base64

# GitHub Configuration
repo_full_name = os.getenv("GITHUB_REPOSITORY", "serc-courses/project-1-team-30")
REPO_OWNER, REPO_NAME = repo_full_name.split('/')
REPO_ACCESS_TOKEN = os.getenv("REPO_ACCESS_TOKEN")
BASE_URL = "https://api.github.com"

def get_headers():
    if not REPO_ACCESS_TOKEN:
        raise ValueError("REPO_ACCESS_TOKEN is not set in environment variables.")
    return {
        "Authorization": f"Bearer {REPO_ACCESS_TOKEN}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "Refactoring-Pipeline-Bot"
    }

def create_branch(branch_name):
    """Creates a new branch on GitHub."""
    print(f"Creating branch: {branch_name}")
    headers = get_headers()
    
    # 1. Get SHA of master branch
    url = f"{BASE_URL}/repos/{REPO_OWNER}/{REPO_NAME}/git/refs/heads/master"
    response = requests.get(url, headers=headers)
    if response.status_code != 200:
        print(f"Failed to get main branch SHA: {response.status_code} - {response.text}")
        response.raise_for_status()
        
    sha = response.json()['object']['sha']
    
    # 2. Create new branch
    url = f"{BASE_URL}/repos/{REPO_OWNER}/{REPO_NAME}/git/refs"
    payload = {
        "ref": f"refs/heads/{branch_name}",
        "sha": sha
    }
    response = requests.post(url, json=payload, headers=headers)
    if response.status_code not in [201, 202]:
        print(f"Failed to create branch: {response.status_code} - {response.text}")
        response.raise_for_status()

def commit_file(branch_name, file_path, content, commit_message):
    """Commits a single file change to a branch."""
    print(f"Committing file: {file_path}")
    headers = get_headers()
    
    # First get the file's current blob SHA (if it exists)
    url = f"{BASE_URL}/repos/{REPO_OWNER}/{REPO_NAME}/contents/{file_path}?ref={branch_name}"
    response = requests.get(url, headers=headers)
    sha = None
    if response.status_code == 200:
        sha = response.json().get('sha')
    
    content_encoded = base64.b64encode(content.encode()).decode()
    
    url = f"{BASE_URL}/repos/{REPO_OWNER}/{REPO_NAME}/contents/{file_path}"
    payload = {
        "message": commit_message,
        "content": content_encoded,
        "branch": branch_name
    }
    if sha:
        payload["sha"] = sha
        
    response = requests.put(url, json=payload, headers=headers)
    if response.status_code not in [200, 201]:
        print(f"Failed to commit file: {response.status_code} - {response.text}")
        response.raise_for_status()

def create_pull_request(branch_name, title, body):
    """Opens a PR from the specified branch to main."""
    print(f"Opening Pull Request for branch: {branch_name}")
    url = f"{BASE_URL}/repos/{REPO_OWNER}/{REPO_NAME}/pulls"
    headers = get_headers()
    payload = {
        "title": title,
        "body": body,
        "head": branch_name,
        "base": "master"
    }
    response = requests.post(url, json=payload, headers=headers)
    if response.status_code not in [201, 202]:
        print(f"Failed to create PR: {response.status_code} - {response.text}")
        response.raise_for_status()
        
    return response.json().get('html_url')

if __name__ == "__main__":
    print("GitHub PR module loaded.")
