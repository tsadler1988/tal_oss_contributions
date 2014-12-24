require 'json'
require 'time'
require 'dashing'
require 'octokit'

SCHEDULER.every '5s' do


  openedPulls = pull_count_by_status('fmtvp/tal', 'all')
  closedPulls = pull_count_by_status('fmtvp/tal', 'closed')

  leadTime = calculateLeadTime(closedPulls)

  send_event(
      'totalOpenedPullRequests',
      {
          current: openedPulls.count
      }
  )

  send_event(
      'totalClosedPullRequests',
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
            value: 1
        }
      end
    rescue Octokit::Error => exception
      Raven.capture_exception(exception)
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
