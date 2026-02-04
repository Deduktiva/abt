Rails.application.routes.draw do
  resource :issuer_company, only: [:show, :edit, :update] do
    get :png_logo, on: :member
  end
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  resources :attachments
  resources :customers do
    resources :customer_contacts, only: [:new, :create] do
      get :cancel_new, on: :collection
    end
  end
  resources :customer_contacts, only: [:edit, :update, :destroy] do
    get :cancel_edit, on: :member
  end
  resources :invoices do
    member do
      get 'preview'
      get 'preview_email'
      get 'book'
      post 'book'
      post 'send_email'
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

  root to: "home#index"
end
