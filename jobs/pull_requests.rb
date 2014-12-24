require 'json'
require 'time'
require 'dashing'
require 'octokit'

SCHEDULER.every '10s' do


  openedPulls = pull_count_by_status('fmtvp/tal', 'open')
  closedPulls = pull_count_by_status('fmtvp/tal', 'closed')

  #puts("Closed pulls:")
  #puts(closedPulls)

  closedPulls.each do |pull|
    unless pull[:mergeddate]
      closedPulls.delete(pull)
    end
  end

  #outside_tal(openedPulls, closedPulls)

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
          current: closedPulls.count
      }
  )

  send_event(
      'totalPullRequestsLeadTime',
      {
          current: leadTime
      }
  )

end

def pull_count_by_status(repo, state)
  events = []
    begin
      client = Octokit::Client.new(
 #         :login => ,
#          :access_token =>
      )
      client.auto_paginate = true

      pulls = client.pull_requests(repo, {:state=>state})
      pulls.each do |pull|
        state_desc = (pull.state == 'open') ? 'opened' : 'closed'
        events << {
            type: "pull_count_#{state_desc}",
            openeddatetime: pull.created_at,
            closeddatetime: pull.closed_at,
            key: pull.state.dup,
            mergeddate: pull.merged_at,
            contributor: pull.user.login
        }
      end
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
