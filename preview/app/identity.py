"""Who is asking: the email IAP signed into the request, verified, never a plain header."""
from fastapi import HTTPException, Request

from .config import Settings

IAP_CERTS = "https://www.gstatic.com/iap/verify/public_key"
IAP_ISSUER = "https://cloud.google.com/iap"


def verify_iap_jwt(token: str, audience: str) -> str:
    """The verified email in IAP's `x-goog-iap-jwt-assertion`, or an HTTPException."""
    from google.auth.transport import requests as g_requests
    from google.oauth2 import id_token

    try:
        claims = id_token.verify_token(token, g_requests.Request(), audience=audience,
                                       certs_url=IAP_CERTS)
    except Exception as e:  # any failure to verify is a refusal
        raise HTTPException(401, f"IAP assertion not valid: {e}") from None
    if claims.get("iss") != IAP_ISSUER or not claims.get("email"):
        raise HTTPException(401, "IAP assertion has no email from IAP")
    return claims["email"].lower()


def current_email(request: Request, settings: Settings) -> str:
    token = request.headers.get("x-goog-iap-jwt-assertion")
    if token:
        if not settings.iap_audience:
            raise HTTPException(500, "PREVIEW_IAP_AUDIENCE is not set")
        return verify_iap_jwt(token, settings.iap_audience)
    if settings.dev_email and not settings.on_cloud_run:
        return settings.dev_email.lower()
    raise HTTPException(401, "sign in through IAP")
