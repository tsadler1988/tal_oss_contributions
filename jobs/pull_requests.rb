require 'json'
require 'time'
require 'dashing'
require 'octokit'

$tal_team
$fmtvp_org
$tal_team_id = 321953

SCHEDULER.every '10s' do


  openedPulls = pull_count_by_status('fmtvp/tal', 'open')
  closedPulls = pull_count_by_status('fmtvp/tal', 'closed')
  mergedPulls = []

  closedPulls.each do |pull|
    if pull[:mergeddate]
      mergedPulls << pull
    end
  end

  leadTime = calculateLeadTime(closedPulls)

  send_event(
      'totalOpenPullRequests',
      {
          current: openedPulls.count
      }
  )

  send_event(
      'totalMergedPullRequests',
      {
          current: mergedPulls.count
      }
  )

  send_event(
      'totalPullRequestsLeadTime',
      {
          current: leadTime
      }
  )

  set_tal_team()
  #set_fmtvp_org()

  outside_tal(openedPulls, closedPulls)
  #outside_fmtvp(openedPulls, closedPulls)

end

def pull_count_by_status(repo, state)
  events = []
  client = Octokit::Client.new(
      :login => "tsadlerBBC",
      :access_token => "50c3b73f233cb958811ac2cf0140f789f534a9f2"
  )
  client.auto_paginate = true

  pulls = client.pull_requests(repo, {:state => state})
  pulls.each do |pull|
    events << {
        openeddatetime: pull.created_at,
        closeddatetime: pull.closed_at,
        mergeddate: pull.merged_at,
        contributor: pull.user.login
    }
  end

  client = nil
  Octokit.reset!
  return events

end

def calculateLeadTime(closedPulls)
  averageLeadTime = 0.0

  closedPulls.each do |pull|
    leadTime = (pull[:closeddatetime].to_date - pull[:openeddatetime].to_date).to_i
    averageLeadTime += leadTime
  end

  averageLeadTime = averageLeadTime / closedPulls.count

  return averageLeadTime.round(2)
end

def set_tal_team()

  $tal_team = []

  client = Octokit::Client.new(
      :login => "tsadlerBBC",
      :access_token => "50c3b73f233cb958811ac2cf0140f789f534a9f2"
  )
  client.auto_paginate = true

  team = client.team_members($tal_team_id)

  team.each do |member|
    $tal_team << member.login
  end

  client = nil
  Octokit.reset!
end

def set_fmtvp_org()
  client = Octokit::Client.new(
      :login => "tsadlerBBC",
      :access_token => "50c3b73f233cb958811ac2cf0140f789f534a9f2"
  )
  client.auto_paginate = true

  client = nil
  Octokit.reset!
end

def outside_tal (open, merged)

  mergedOutsideTal = []
  openOutsideTal = []

  merged.each do |pull|
    unless tal_team_member?(pull[:contributor])
      mergedOutsideTal << pull
    end
  end

  open.each do |pull|
    unless tal_team_member?(pull[:contributor])
      openOutsideTal << pull
    end
  end

  leadTime = calculateLeadTime(mergedOutsideTal)

  send_event(
      'nonTalPullRequestsOpen',
      {
          current: openOutsideTal.count
      }
  )

  send_event(
      'nonTalPullRequestsMerged',
      {
          current: mergedOutsideTal.count
      }
  )

  send_event(
      'nonTalPullRequestsLeadTime',
      {
          current: leadTime
      }
  )

end

def tal_team_member?(user)
  result = $tal_team.include? user
  return result
end

def fmtvp_org_member?(user)
end