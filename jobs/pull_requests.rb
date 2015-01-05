require 'json'
require 'time'
require 'dashing'
require 'octokit'

$tal_team
$fmtvp_org
$tal_team_id = 321953
$login = ''
$access_token = ''

SCHEDULER.every '1m' do
  # can we listen to POSTs instead?


  openedPulls = pull_count_by_status('fmtvp/tal', 'open')
  closedPulls = pull_count_by_status('fmtvp/tal', 'closed')
  mergedPulls = []

  closedPulls.each do |pull|
    if pull[:mergeddate]
      mergedDate = pull[:mergeddate].to_date
      if mergedDate > Date.parse('2014-06-01')
        mergedPulls << pull
      end
    end
  end

  leadTime = calculateLeadTime(mergedPulls)

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
  set_fmtvp_org()

  outside_tal(openedPulls, mergedPulls)
  outside_fmtvp(openedPulls, mergedPulls)

end

def pull_count_by_status(repo, state)
  events = []
  client = Octokit::Client.new(
      :login => $login,
      :access_token => $access_token
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

  if closedPulls.count > 0

    closedPulls.each do |pull|
      leadTime = (pull[:closeddatetime].to_date - pull[:openeddatetime].to_date).to_i
      averageLeadTime += leadTime
    end

    averageLeadTime = averageLeadTime / closedPulls.count
  end

  return averageLeadTime.round(2)
end

def set_tal_team()

  $tal_team = []

  client = Octokit::Client.new(
      :login => $login,
      :access_token => $access_token
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
  $fmtvp_org = []

  client = Octokit::Client.new(
      :login => $login,
      :access_token => $access_token
  )
  client.auto_paginate = true

  org = client.organization_members('fmtvp')

  org.each do |member|
    $fmtvp_org << member.login
  end

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

def outside_fmtvp (open, merged)

  mergedOutsideFmtvp = []
  openOutsideFmtvp = []

  merged.each do |pull|
    unless fmtvp_org_member?(pull[:contributor])
      mergedOutsideFmtvp << pull
    end
  end

  open.each do |pull|
    unless fmtvp_org_member?(pull[:contributor])
      openOutsideFmtvp << pull
    end
  end

  leadTime = calculateLeadTime(mergedOutsideFmtvp)

  send_event(
      'nonFmtvpPullRequestsOpen',
      {
          current: openOutsideFmtvp.count
      }
  )

  send_event(
      'nonFmtvpPullRequestsMerged',
      {
          current: mergedOutsideFmtvp.count
      }
  )

  send_event(
      'nonFmtvpPullRequestsLeadTime',
      {
          current: leadTime
      }
  )

end

def tal_team_member?(user)
  return $tal_team.include? user
end

def fmtvp_org_member?(user)
  return $fmtvp_org.include? user
end