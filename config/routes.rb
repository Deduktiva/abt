Rails.application.routes.draw do
  resource :issuer_company, only: [:show, :edit, :update] do
    get :png_logo, on: :member
  end
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  resources :attachments
  resources :customers
  resources :invoices do
    member do
      get 'preview'
      get 'preview_email'
      get 'book'
      post 'book'
      post 'send_email'
      post 'mark_paid'
      post 'mark_unpaid'
    end
    collection do
      post 'bulk_send_emails'
    end
  end
  resources :delivery_notes do
    member do
      get 'preview'
      get 'preview_email'
      get 'publish'
      post 'publish'
      post 'send_email'
      get 'pdf'
      post 'unpublish'
      post 'upload_acceptance'
      post 'delete_acceptance'
      post 'convert_to_invoice'
    end
    collection do
      post 'bulk_send_emails'
    end
  end
  resources :products
  resources :projects
  resources :sales_tax_customer_classes
  resources :sales_tax_product_classes
  resources :sales_tax_rates

  resource :jobs_status, only: [:show], controller: 'jobs_status'

  get    "/login"                   => "sessions#new",      as: :login
  delete "/logout"                  => "sessions#destroy",  as: :logout
  get    "/auth/:provider/callback" => "sessions#callback"
  get    "/auth/failure"            => "sessions#failure", as: :auth_failure

  get    "/invites/:token"        => "invites#show",   as: :invite
  post   "/invites/:token/accept" => "invites#accept", as: :invite_accept

  resources :users, only: [:index, :show] do
    member do
      post :block
      post :unblock
    end
  end
  resources :user_invites, only: [:index, :create, :destroy]
  resources :audit_events, only: [:index]

  get  "/profile"       => "profile#show",  as: :profile
  post "/profile/block" => "profile#block", as: :profile_block

  scope path: "/profile", as: :profile do
    resources :sessions, only: [:index, :destroy], controller: "profile/sessions"
  end

  root to: "home#index"
end
