#!/bin/bash

# Define application routes here using the DSL
# Example:
# b:GET / home#index
# b:POST /posts posts#create
b:GET / home#index
b:GET /posts posts#index
b:GET /posts/:id posts#show
b:POST /posts posts#create

