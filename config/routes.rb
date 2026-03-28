# frozen_string_literal: true

KeycloakRails::Engine.routes.draw do
  get "login",    to: "sessions#new",      as: :login
  get "callback", to: "sessions#callback", as: :callback
  delete "logout", to: "sessions#destroy",  as: :logout
end
