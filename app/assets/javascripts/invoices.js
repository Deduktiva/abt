// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

var invoiceLinesApp = angular.module('invoiceLinesApp', ['ngResource', 'ProductsServices']);

invoiceLinesApp.factory('SalesTaxProductClasses', [
    '$resource',
    function($resource) {
        return $resource('/sales_tax_product_classes/:id', {}, {
            query: {
                method: 'GET',
                url: '/sales_tax_product_classes.json',
                isArray: true,
                cache: true
            }
        });
    }
]);

invoiceLinesApp.controller('InvoiceLinesController', [
    '$scope', '$log', 'SalesTaxProductClasses', 'Products',
    function($scope, $log, SalesTaxProductClasses, Products) {
        $scope.products = Products.query();
        $scope.setLines = function(lines) {
            return $scope.lines = lines;
        };
        $scope.addLine = function() {
            return $scope.lines.push({
                title: "",
                type: "text"
            });
        };
        $scope.removeLine = function(line) {
            var idx;
            idx = $scope.lines.indexOf(line);
            return $scope.lines.splice(idx, 1);
        };
        $scope.moveLineUp = function(line) {
            var idx = $scope.lines.indexOf(line);
            if (idx == 0) {
                return;
            }
            $scope.lines.splice(idx, 1);
            $scope.lines.splice(idx-1, 0, line);
        };
        $scope.moveLineDown = function(line) {
            var idx = $scope.lines.indexOf(line);
            if (idx == $scope.lines.length) {
                return;
            }
            $scope.lines.splice(idx, 1);
            $scope.lines.splice($scope.lines.length, 0, line);
        };
        $scope.sales_tax_product_classes = SalesTaxProductClasses.query();
        $scope.invoice_total = function() {
            return _.reduce($scope.lines, function(memo, line) {
                var line_sum;
                line_sum = 0;
                if (line.rate && line.quantity) {
                    line_sum = line.rate * line.quantity;
                }
                return memo + line_sum;
            }, 0);
        };
        $scope.saveLines = function() {
            $('#invoice_lines').val(JSON.stringify($scope.lines));
            return true;
        };
        $scope.takeOverForm = function() {
            $('.form-actions').hide();
            return false;
        };
        return true;
    }
]);


invoiceLinesApp.controller('InvoiceLinesLineController', [
    '$scope', '$log',
    function($scope, $log) {
        $scope.isProductDropdownShown = false;
        $scope.showProductDropdown = function() {
            $scope.isProductDropdownShown = !$scope.isProductDropdownShown;
        };
        $scope.useSelectedProduct = function() {
            $scope.line.title = $scope.product_dropdown_product.title;
            $scope.line.description = $scope.product_dropdown_product.description;
            $scope.line.rate = parseFloat($scope.product_dropdown_product.rate);
            if (!!$scope.line.quantity) {
                $scope.line.quantity = 1;
            }
            $scope.isProductDropdownShown = false;
        };
        return true;
    }
]);
