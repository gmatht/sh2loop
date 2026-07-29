#!/bin/bash
# Demonstrates Perl::Critic violation for integer with leading zeros (07777)
# This triggers via the ls command which generates mode & 07777 in Perl
ls -la /tmp
