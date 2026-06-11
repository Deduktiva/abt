Rails.application.routes.draw do
  constraints(CustomerPortalHostConstraint.new) do
    scope module: :customer_portal do
      get  "delivery-acceptance/:token", to: "acceptances#show",   as: :delivery_acceptance_upload
      post "delivery-acceptance/:token", to: "acceptances#create", as: :delivery_acceptance_upload_submit
      get  "/", to: "pages#root", as: :public_root
      get  "*path", to: "pages#not_found", format: false
    end
  end

  resource :session, only: [ :new, :destroy ], controller: "sessions" do
    collection do
      post :options
      post :verify
    end
  end

  get "invites", to: "invites#show", as: :invite
  post "invites/options", to: "invites#options", as: :options_invite
  post "invites/verify", to: "invites#verify", as: :verify_invite

  namespace :account do
    resource :profile, only: [ :show ]
    resources :sessions, only: [ :index, :destroy ] do
      collection do
        delete :destroy_all
      end
    end
    resources :credentials, only: [ :index, :new, :destroy ] do
      collection do
        post :options
        post :verify
      end
    end
    resources :emails, only: [ :index, :create, :destroy ]
    get "email_confirmations", to: "email_confirmations#show", as: :email_confirmation
    resource :block, only: [ :create ]
    resources :audit_events, only: [ :index ]
  end

  resources :users, only: [ :index, :show ] do
    member do
      post :block
      post :unblock
      post :reset_passkeys
      get :audit
      patch :update_groups
      patch :update_teams
    end
    resources :emails, only: [ :create, :update, :destroy ], controller: "users/emails"
  end

  resources :user_invites, only: [ :create, :index ]

  resources :groups
  resources :teams

  resource :issuer_company, only: [ :show, :edit, :update ] do
    get :png_logo, on: :member
  end
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  resources :attachments, only: [ :show ]
  resources :customers do
    member do
      post :verify_vat_id
    end
    resources :customer_contacts, only: [ :new, :create ]
  end
  resources :customer_contacts, only: [ :show, :edit, :update, :destroy ]
  resources :invoices do
    member do
      get "preview"
      get "preview_email"
      get "preview_email_html"
      post "publish"
      post "send_email"
      post "mark_paid"
      post "mark_unpaid"
      post "import_lines"
    end
    collection do
      post "bulk_send_emails"
    end
  end
  resources :delivery_notes do
    member do
      get "preview"
      get "preview_email"
      get "preview_email_html"
      post "publish"
      post "send_email"
      get "pdf"
      post "unpublish"
      post "upload_acceptance"
      post "delete_acceptance"
      post "convert_to_invoice"
      post "accept_acceptance"
      post "reject_acceptance"
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
