import sh

def tor_has_bootstrapped() -> bool:
    try:
        sh.systemctl("is-active", "tails-tor-has-bootstrapped.target")
        return True
    except sh.ErrorReturnCode:
        return False
