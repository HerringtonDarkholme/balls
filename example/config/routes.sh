#!/usr/bin/env bash
#
# Example App Routes
#

# Root route
get "/" "home#index"

# Posts CRUD
resources "posts"
