import subprocess
import sys
import time

def check_gcloud(project_id: str, service_account: str, roles: list[str]) -> bool:
    command = [
        'gcloud',
        'projects',
        'get-iam-policy',
        project_id,
        '--format=value(bindings[].role)',
        f'--filter=bindings.members:serviceAccount:{service_account}',
    ]

    result = subprocess.run(command, capture_output=True, text=True, shell=True, check=True)

    return set(roles).issubset(set(result.stdout.strip().split(";")))

def loop_check_gcloud(project_id: str, service_account: str, roles: list[str], max_checks: int = 10, pause: int = 5) -> None:
    for i in range(max_checks):
        try:
            if check_gcloud(project_id, service_account, roles):
                print("All roles found")
                sys.exit(0)
        except subprocess.CalledProcessError as e:
            print(f"Error checking roles: {e}")
            sys.exit(1)
        print(f"Not all roles found. {max_checks -i } checks remaining")
        time.sleep(pause)

    print("All roles not found")
    sys.exit(1)

if __name__ == "__main__":
    _, project_id, service_account, *roles = sys.argv
    loop_check_gcloud(project_id, service_account, roles)