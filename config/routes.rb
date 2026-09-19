Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => "health#show"

  resources :documents, only: [ :index, :show, :create, :destroy ]
  post "query" => "queries#create"
end
