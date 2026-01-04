"""Application exceptions."""

from fastapi import HTTPException, status


class AppException(Exception):
    """Base application exception."""

    def __init__(self, message: str, code: str = "APP_ERROR"):
        self.message = message
        self.code = code
        super().__init__(message)


class NotFoundError(AppException):
    """Resource not found."""

    def __init__(self, resource: str, identifier: str):
        super().__init__(
            message=f"{resource} with id '{identifier}' not found",
            code="NOT_FOUND",
        )


class ValidationError(AppException):
    """Validation error."""

    def __init__(self, message: str):
        super().__init__(message=message, code="VALIDATION_ERROR")


class AuthenticationError(AppException):
    """Authentication failed."""

    def __init__(self, message: str = "Authentication failed"):
        super().__init__(message=message, code="AUTH_ERROR")


# HTTP Exceptions
credentials_exception = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Could not validate credentials",
    headers={"WWW-Authenticate": "Bearer"},
)

forbidden_exception = HTTPException(
    status_code=status.HTTP_403_FORBIDDEN,
    detail="Not enough permissions",
)
