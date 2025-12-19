#!/usr/bin/env bash
#
# Home Controller
#

index_action() {
    title="Welcome to Bash on Balls"
    tagline="A Rails parody web framework written entirely in Bash"
    render "home/index"
}
