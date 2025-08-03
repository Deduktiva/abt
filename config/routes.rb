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
      get 'book'
      post 'book'
      post 'send_email'
    end
  end
  resources :products
  resources :projects
  resources :sales_tax_customer_classes
  resources :sales_tax_product_classes
  resources :sales_tax_rates

  root to: "home#index"
end
