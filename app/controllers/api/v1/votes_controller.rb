class Api::V1::VotesController < ApplicationController
  def create
    with_user_id do |user_id|
      task_id = params.require(:task_id)
      with_task(task_id) do
        vote = Vote.find_or_create_by! task_id: task_id, user_id: user_id
        rep = { id: vote.id, user_id: user_id, task_id: task_id, revision: vote.revision }
        render json: rep, status: 201
      end
    end
  end

  def destroy
    with_user_id do |user_id|
      task_id = params.require(:task_id)
      with_task(task_id) do
        vote = Vote.find_by! task_id: task_id, user_id: user_id
        vote.destroy
        render nothing: true, content_type: "application/json"
      end
    end
  end

  def index
    with_user_id do |user_id|
      if params[:task_id]
        for_task(user_id)
      elsif params[:list_id]
        for_list(user_id)
      elsif
        error_resp
      end
    end
  end

  def for_task(user_id)
    vote = Vote.where(task_id: params.require(:task_id), user_id: user_id).first
    if vote
      json = { id: vote.id, user_id: user_id, task_id: vote.task_id, revision: vote.revision }
      render json: json
    elsif
      not_found_resp
    end
  end

  def for_list(user_id)
    list_id = params.require(:list_id)
    with_tasks(list_id) do |tasks|
      votes = tasks.map do |task|
        Vote.where(task_id: task['id'], user_id: user_id).first
      end
      votes.compact!
      render json: votes
    end
  end

  private

  def error_resp
    render json: { error: :server_error }, status: 500
  end

  def not_found_resp
    render json: { error: :not_found }, status: 404
  end

  def with_user_id
    res = get_w("api/v1/user")
    Rails.logger.error "*"*80
    Rails.logger.error res.body
    Rails.logger.error "*"*80

    if res.code == '200'
      json = JSON.parse(res.body)
      user_id = json["id"]
      yield(user_id)
    elsif res.code == '404'
      not_found_resp
    else
      error_resp
    end
  end

  def get_w(path)
    uri = URI("http://a.wunderlist.com/#{path}")
    req = Net::HTTP::Get.new(uri)
    req["X-Client-ID"] = request.headers["X-Client-ID"]
    req["X-Access-Token"] = request.headers["X-Access-Token"]
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request req }
  end

  def with_task(task_id)
    res = get_w("api/v1/tasks/#{task_id}")
    Rails.logger.error "*"*80
    Rails.logger.error res.body
    Rails.logger.error "*"*80

    if res.code == '200'
      yield
    elsif res.code == '404'
      not_found_resp
    else
      error_resp
    end
  end

  def with_tasks(list_id)
    res = get_w("api/v1/tasks?list_id=#{list_id}")
    Rails.logger.error "*"*80
    Rails.logger.error res.body
    Rails.logger.error "*"*80

    if res.code == '200'
      tasks = JSON.parse(res.body)
      yield(tasks)
    elsif res.code == '404'
      not_found_resp
    else
      error_resp
    end
  end
end
