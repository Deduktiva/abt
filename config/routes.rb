Rails.application.routes.draw do
  resource :session, only: [ :new, :destroy ], controller: "sessions" do
    collection do
      post :options
      post :verify
    end
  end

  resources :invites, only: [ :show ], param: :token do
    member do
      post :options
      post :verify
    end
  end

  namespace :account do
    resource :profile, only: [ :show ]
    resources :sessions, only: [ :index, :destroy ]
    resources :credentials, only: [ :index, :new, :destroy ] do
      collection do
        post :options
        post :verify
      end
    end
    resources :emails, only: [ :index, :create, :destroy ]
    resources :email_confirmations, only: [ :show ], param: :token
    resource :block, only: [ :create ]
    resources :audit_events, only: [ :index ]
  end

  resources :users, only: [ :index, :show ] do
    member do
      post :block
      post :unblock
      post :reset_passkeys
      get :audit
    end
    resources :emails, only: [ :create, :update, :destroy ], controller: "users/emails"
  end

  resources :user_invites, only: [ :new, :create, :index ]

  resource :issuer_company, only: [ :show, :edit, :update ] do
    get :png_logo, on: :member
  end
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  resources :attachments, only: [ :show ]
  resources :customers
  resources :invoices do
    member do
      get "preview"
      get "preview_email"
      get "book"
      post "book"
      post "send_email"
      post "mark_paid"
      post "mark_unpaid"
    end
    collection do
      post "bulk_send_emails"
    end
  end
  resources :delivery_notes do
    member do
      get "preview"
      get "preview_email"
      get "publish"
      post "publish"
      post "send_email"
      get "pdf"
      post "unpublish"
      post "upload_acceptance"
      post "delete_acceptance"
      post "convert_to_invoice"
    end
    collection do
      post "bulk_send_emails"
    end
  end
  resources :products
  resources :projects
  resources :sales_tax_customer_classes
  resources :sales_tax_product_classes
  resources :sales_tax_rates

  resource :jobs_status, only: [ :show ], controller: "jobs_status"

  root to: "home#index"
end
