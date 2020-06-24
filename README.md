A very hacky dashboard to get InnerSource and Open Source Pull Request metrics using Dashing and Octokit

## Quick start
Update `jobs/pull_requests.rb` with a GitHub login and access token:
```
$login = '<your-login>'
$access_token = '<your-token>'
```

To run (assuming you have Ruby and Bundler):
```
bundle install
dashing start
```