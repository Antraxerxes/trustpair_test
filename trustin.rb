require "json"
require "net/http"

require 'net/http'
require 'json'
require 'uri'

class TrustIn
  def initialize(evaluations)
    @evaluations = evaluations
  end

  def update_score
    @evaluations.each do |evaluation|
      if evaluation.type == "SIREN" || evaluation.type == "VAT"
        if evaluation_needs_api_update?(evaluation)
          company_state = fetch_company_state(evaluation.value)
          update_evaluation_based_on_state(evaluation, company_state)
        elsif evaluation.score >= 50
          adjust_score_for_high_score(evaluation)
        elsif evaluation.score > 0
          adjust_score_for_low_score(evaluation)
        end
      end
    end
  end

  private

  def evaluation_needs_api_update?(evaluation)
    evaluation.state == "unconfirmed" && evaluation.reason == "ongoing_database_update" && evaluation.score > 0
  end

  def fetch_company_state(siren_value)
    if evaluation.type == "SIREN"
      uri = URI("https://public.opendatasoft.com/api/records/1.0/search/?dataset=economicref-france-sirene-v3&q=#{siren_value}&sort=datederniertraitementetablissement&refine.etablissementsiege=oui")
      response = Net::HTTP.get(uri)
      parsed_response = JSON.parse(response)
      parsed_response["records"].first["fields"]["etatadministratifetablissement"]
    else 
      #just dont move value for vat. could use a stub 
      evaluation.state
  end

  def update_evaluation_based_on_state(evaluation, company_state)
    if company_state == "Actif"
      evaluation.state = "favorable"
      evaluation.reason = "company_opened"
      evaluation.score = 100
    else
      evaluation.state = "unfavorable"
      evaluation.reason = "company_closed"
      evaluation.score = 100
    end
  end

  def adjust_score_for_high_score(evaluation)
    if evaluation.state == "unconfirmed" && evaluation.reason == "unable_to_reach_api"
      adjustment = evaluation.type == "SIREN" ? 5 : 1
      evaluation.score -= adjustment
    elsif evaluation.state == "favorable"
      adjustment = evaluation.type == "SIREN" ? 1 : 3
      evaluation.score -= adjustment
    end
  end

  def adjust_score_for_low_score(evaluation)
    if (evaluation.state == "unconfirmed" && evaluation.reason == "unable_to_reach_api") || evaluation.state == "favorable"
      adjustment = evaluation.type == "SIREN" ? 1 : 3
      evaluation.score -= adjustment
    end
  end
end

class Evaluation
  attr_accessor :type, :value, :score, :state, :reason

  def initialize(type:, value:, score:, state:, reason:)
    @type = type
    @value = value
    @score = score
    @state = state
    @reason = reason
  end

  def to_s()
    "#{@type}, #{@value}, #{@score}, #{@state}, #{@reason}"
  end
end
