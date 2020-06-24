require 'json'
require 'time'
require 'dashing'
require 'octokit'

$orion_team
$bbc_org
$login = ''
$access_token = ''

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

def set_orion_team()

  $orion_team = []

  client = Octokit::Client.new(
      :login => $login,
      :access_token => $access_token
  )
  client.auto_paginate = true

  $team_id = client.team_by_name("bbc", "orion")[:id]

  team = client.team_members($team_id)

  team.each do |member|
    $orion_team << member.login
  end

  client = nil
  Octokit.reset!
end

def set_bbc_org()
  $bbc_org = []

  client = Octokit::Client.new(
      :login => $login,
      :access_token => $access_token
  )
  client.auto_paginate = true

  org = client.organization_members('bbc')

  org.each do |member|
    $bbc_org << member.login
  end

  client = nil
  Octokit.reset!
end

def orion (open, merged)

  mergedOrion = []
  openOrion = []

  merged.each do |pull|
    if orion_team_member?(pull[:contributor])
      mergedOrion << pull
    end
  end

  open.each do |pull|
    if orion_team_member?(pull[:contributor])
      openOrion << pull
    end
  end

  leadTime = calculateLeadTime(mergedOrion)

  send_event(
      'orionOpenPullRequests',
      {
          current: openOrion.count
      }
  )

  send_event(
      'orionMergedPullRequests',
      {
          current: mergedOrion.count
      }
  )

  send_event(
      'orionPullRequestsLeadTime',
      {
          current: leadTime
      }
  )

end

def bbc (open, merged)

  mergedBbc = []
  openBbc = []

  merged.each do |pull|
    if (bbc_org_member?(pull[:contributor])) && !(orion_team_member?(pull[:contributor]))
      mergedBbc << pull
    end
  end

  open.each do |pull|
    if (bbc_org_member?(pull[:contributor])) && !(orion_team_member?(pull[:contributor]))
      openBbc << pull
    end
  end

  leadTime = calculateLeadTime(mergedBbc)

  send_event(
      'bbcPullRequestsOpen',
      {
          current: openBbc.count
      }
  )

  send_event(
      'bbcPullRequestsMerged',
      {
          current: mergedBbc.count
      }
  )

  send_event(
      'bbcPullRequestsLeadTime',
      {
          current: leadTime
      }
  )

end

def external (open, merged)

  mergedExternal = []
  openExternal = []

  merged.each do |pull|
    unless bbc_org_member?(pull[:contributor])
      mergedExternal << pull
    end
  end

  open.each do |pull|
    unless bbc_org_member?(pull[:contributor])
      openExternal << pull
    end
  end

  leadTime = calculateLeadTime(mergedExternal)

  send_event(
      'externalPullRequestsOpen',
      {
          current: openExternal.count
      }
  )

  send_event(
      'externalPullRequestsMerged',
      {
          current: mergedExternal.count
      }
  )

  send_event(
      'externalPullRequestsLeadTime',
      {
          current: leadTime
      }
  )

end

def orion_team_member?(user)
  return $orion_team.include? user
end

def bbc_org_member?(user)
  return $bbc_org.include? user
end

puts('starting')

openedPulls = pull_count_by_status('bbc/morty-docs', 'open')
closedPulls = pull_count_by_status('bbc/morty-docs', 'closed')
mergedPulls = []

closedPulls.each do |pull|
  if pull[:mergeddate]
    mergedDate = pull[:mergeddate].to_date
    if mergedDate > Date.parse('2020-01-01')
      mergedPulls << pull
    end
  end
end

puts('got pulls')

set_orion_team()
puts('got Orion')

set_bbc_org()
puts('got BBC')

orion(openedPulls, mergedPulls)
bbc(openedPulls, mergedPulls)
external(openedPulls, mergedPulls)

puts('Done')