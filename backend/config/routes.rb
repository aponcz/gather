Rails.application.routes.draw do
  devise_for :users,
             path: "api/v1/auth",
             defaults: { format: :json },
             skip: [:omniauth_callbacks],
             controllers: {
               sessions: "api/v1/devise/sessions",
               registrations: "api/v1/devise/registrations",
               passwords: "api/v1/devise/recoveries",
               confirmations: "api/v1/devise/confirmations"
             }

  devise_scope :user do
    post "api/v1/auth/sign_in", to: "api/v1/devise/sessions#create"
    delete "api/v1/auth/sign_out", to: "api/v1/devise/sessions#destroy"
  end

  get "/health", to: "health#show"

  namespace :api do
    namespace :v1 do
      post "/auth/register", to: "auth#register"
      post "/auth/login", to: "auth#login"
      post "/auth/switch-company", to: "auth#switch_company"
      post "/auth/forgot-password", to: "auth#forgot_password"
      post "/auth/reset-password", to: "auth#reset_password"
      get "/me", to: "auth#me"
      resource :company, only: %i[show update]
      resources :company_members, only: %i[index create update]

      resources :contacts, only: %i[index show create update]
      resources :invites, only: %i[index show create update] do
        collection do
          post :bulk_create
        end
        member do
          post :add_contacts
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
