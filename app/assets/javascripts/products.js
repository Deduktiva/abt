// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

angular.module('ProductsServices', ['ngResource']).
    factory('Products', [
        '$resource',
        function ($resource) {
            return $resource('/products/:id', {}, {
                query: {
                    method: 'GET',
                    url: '/products.json',
                    isArray: true,
                    cache: true
                }
            });
        }
    ]);
