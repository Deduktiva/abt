Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  resources :attachments
  resources :customers
  resources :invoices do
    member do
      get 'preview'
      get 'book'
      post 'book'
      post 'test_booking'
    end
  end
  resources :products
  resources :projects
  resources :sales_tax_customer_classes
  resources :sales_tax_product_classes
  resources :sales_tax_rates

  root to: "home#index"
end
