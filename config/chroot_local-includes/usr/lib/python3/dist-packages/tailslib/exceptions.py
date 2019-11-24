#!/usr/bin/python3
#
# Handles our errors.

class TailsLibException(Exception):
	pass

class UnreadableGitRepo(TailsLibException):
	pass

class CheckDirectoryExists(TailsLibException):
	pass

class TorFailedToBoostrapError(Exception):
	pass
