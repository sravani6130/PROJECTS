import detect_smells
import refactor_code
import create_pr
import time
import os

def run_pipeline():
    print("Starting Automated Refactoring Pipeline...")
    
    # 1. Detect Smells
    print("Scanning for design smells...")
    smells = detect_smells.detect_smells("app/src/main/java/org")
    
    if not smells:
        print("No design smells found. Project is clean!")
        return

    print(f"Detected {len(smells)} potential smells.")

    if not os.getenv("REPO_ACCESS_TOKEN"):
        print("CRITICAL ERROR: REPO_ACCESS_TOKEN is not set in environment variables.")
        return
    
    # Process the first 3 detected smells
    num_to_process = min(len(smells), 3)
    print(f"\nProcessing the first {num_to_process} smells in a single PR...")
    
    # Generate a single unique branch for all changes in this run
    timestamp = int(time.time())
    branch_name = f"refactor(Task-3C)-{timestamp}"
    try:
        # 1. Create the branch once
        create_pr.create_branch(branch_name)
        
        processed_files = []
        
        for i in range(num_to_process):
            smell = smells[i]
            file_path = smell['file']
            smell_type = smell['smell']
            print(f"\n[{i+1}/{num_to_process}] Processing {smell_type} in {file_path}...")
            
            # 2. Prepare Context (One or more files)
            files_to_refactor = {}
            try:
                # Always include the primary file identified by Designite
                with open(file_path, 'r') as f:
                    files_to_refactor[file_path] = f.read()
                
                # [OPTIONAL] Heuristic: Look for other files mentioned in the description
                # (e.g. for cyclic dependencies)
                # Designite descriptions often include class names or package names.
                # For now, we stick to the primary file but the LLM can still suggest splitting it.
                
                print(f"Requesting refactored code and rationale for {smell_type}...")
                refactored_files, llm_rationale = refactor_code.get_refactored_code(files_to_refactor, smell_type)
                
                # 3. Create Refactoring Report (Markdown)
                report_content = f"""# Refactoring Report: {smell_type}
## Detected Smell
- **Type**: {smell_type}
- **Primary File**: `{file_path}`
- **Details**: {smell['details']}

## Metrics & Rationale
{llm_rationale}

## Original Fragment(s)
"""
                for path, original in files_to_refactor.items():
                    report_content += f"\n### File: `{path}`\n```java\n{original}\n```\n"

                report_content += "\n## Proposed Refactored Version(s)\n"
                
                if isinstance(refactored_files, dict):
                    for filename, refactored in refactored_files.items():
                        report_content += f"\n### File: `{filename}`\n```java\n{refactored}\n```\n"
                else:
                    report_content += f"\n### Refactored Result\n```java\n{refactored_files}\n```\n"
                
                # 4. Commit the Report to the same branch
                report_filename = f"docs/Task - 3/Task - 3C/{os.path.basename(file_path)}_{i+1}_report.md"
                print(f"Committing report to branch: {report_filename}")
                create_pr.commit_file(branch_name, report_filename, report_content, f"Add refactoring report for {os.path.basename(file_path)}")
                
                processed_files.append(os.path.basename(file_path))
                
                # Longer sleep to respect free-tier rate limits (RPM)
                time.sleep(20)
                
            except Exception as e:
                print(f"Error processing {file_path}: {e}")
                import traceback
                traceback.print_exc()

        # 5. Open a single Pull Request for all committed reports
        if processed_files:
            print("\nOpening a single Pull Request for all reports...")
            pr_title = f"Refactoring Reports: {', '.join(processed_files[:2])}"
            if len(processed_files) > 2:
                pr_title += " and more"
            
            pr_body = "This PR includes automated refactoring reports for the following detected design smells:\n\n"
            for f in processed_files:
                pr_body += f"- {f}\n"
            
            pr_url = create_pr.create_pull_request(branch_name, pr_title, pr_body)
            print(f"Successfully created PR: {pr_url}")
            print(f"All reports pushed to branch: {branch_name}")
        else:
            print("No reports were generated successfully.")

    except Exception as e:
        import traceback
        print("CRITICAL PIPELINE ERROR:")
        traceback.print_exc()

if __name__ == "__main__":
    run_pipeline()
    print("\nPipeline execution complete.")
