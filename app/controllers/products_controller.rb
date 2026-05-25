class ProductsController < ApplicationController
  before_action -> { require_permission!("products.view") }, only: [ :index, :show ]
  before_action -> { require_permission!("products.edit") }, only: [ :new, :create, :edit, :update, :destroy ]

  # GET /products
  def index
    @products = Product.order(:title)
  end

  # GET /products/1
  def show
    @product = Product.find(params[:id])
  end

  # GET /products/new
  def new
    @product = Product.new
  end

  # GET /products/1/edit
  def edit
    @product = Product.find(params[:id])
  end

  # POST /products
  def create
    @product = Product.new(products_params)

    if @product.save
      redirect_to @product, notice: "Product was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PUT /products/1
  def update
    @product = Product.find(params[:id])

    if @product.update(products_params)
      redirect_to @product, notice: "Product was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /products/1
  def destroy
    @product = Product.find(params[:id])
    @product.destroy
    redirect_to products_url
  end

private
  def products_params
    params.require(:product).permit(:title, :description, :rate, :sales_tax_product_class_id)
  end
end
