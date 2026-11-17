Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => "health#show"

  resources :api_keys, only: [ :create ]
  resources :documents, only: [ :index, :show, :create, :destroy ] do
    member do
      post :reindex
    end
  end
  post "query" => "queries#create"
end
