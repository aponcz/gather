Rails.application.routes.draw do
  get "/health", to: "health#show"

  namespace :api do
    namespace :v1 do
      post "/auth/register", to: "auth#register"
      post "/auth/login", to: "auth#login"
      get "/me", to: "auth#me"

      resources :contacts, only: %i[index show create update]
      resources :invites, only: %i[index show create update] do
        member do
          post :send_invite
          post :cancel
          get :download_all_files
        end
        resources :request_items, only: %i[create update destroy]
      end

      resources :uploaded_files, only: %i[show] do
        member do
          post :approve
          post :reject
          get :download_url
        end
      end

      namespace :client do
        post "/magic-link", to: "portal#request_magic_link"
        post "/sessions", to: "portal#create_session"
        get "/invites/:id", to: "portal#show_invite"
        post "/request-items/:id/upload-url", to: "portal#create_upload_url"
        post "/request-items/:id/complete-upload", to: "portal#complete_upload"
        get "/uploaded-files/:id/download_url", to: "portal#download_url"
      end
    end
  end
end
