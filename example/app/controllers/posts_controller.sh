#!/usr/bin/env bash
#
# Posts Controller
#

index_action() {
    title="All Posts"
    # Get all posts
    posts=$(model_all "posts")
    render "posts/index"
}

show_action() {
    title="View Post"
    # Find post by ID (id is set by router)
    post_line=$(model_find "posts" "$id")
    if [[ -z "$post_line" ]]; then
        set_flash error "Post not found"
        redirect_to "/posts"
        return
    fi
    parse_record "posts" "$post_line"
    post_title="$title"
    post_body="$body"
    post_id="$id"
    title="$post_title"
    render "posts/show"
}

new_action() {
    title="New Post"
    post_title=""
    post_body=""
    render "posts/new"
}

create_action() {
    post_title=$(param "title")
    post_body=$(param "body")
    
    # Create the post
    new_id=$(model_create "posts" "title=$post_title" "body=$post_body")
    
    if [[ -n "$new_id" ]]; then
        set_flash notice "Post created successfully!"
        redirect_to "/posts/$new_id"
    else
        set_flash error "Failed to create post"
        title="New Post"
        render "posts/new"
    fi
}

edit_action() {
    post_line=$(model_find "posts" "$id")
    if [[ -z "$post_line" ]]; then
        set_flash error "Post not found"
        redirect_to "/posts"
        return
    fi
    parse_record "posts" "$post_line"
    post_title="$title"
    post_body="$body"
    post_id="$id"
    title="Edit Post"
    render "posts/edit"
}

update_action() {
    post_title=$(param "title")
    post_body=$(param "body")
    
    model_update "posts" "$id" "title=$post_title" "body=$post_body"
    
    set_flash notice "Post updated successfully!"
    redirect_to "/posts/$id"
}

destroy_action() {
    model_destroy "posts" "$id"
    set_flash notice "Post deleted successfully!"
    redirect_to "/posts"
}
