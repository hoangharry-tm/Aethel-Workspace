package domain

import "errors"

var (
	ErrNotFound        = errors.New("not found")
	ErrForbidden       = errors.New("forbidden")
	ErrConflict        = errors.New("conflict")
	ErrHashChainBroken = errors.New("hash chain broken")
	ErrUnauthorized    = errors.New("unauthorized")
	ErrAccountLocked   = errors.New("account locked")
)
