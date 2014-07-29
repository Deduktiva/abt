// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

var invoiceLinesApp = angular.module('invoiceLinesApp', ['ngResource']);

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
    '$scope', '$log', 'SalesTaxProductClasses',
    function($scope, $log, SalesTaxProductClasses) {
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
