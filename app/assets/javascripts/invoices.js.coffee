# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

invoiceLinesApp = angular.module('invoiceLinesApp', ['ngResource'])

invoiceLinesApp.factory 'SalesTaxProductClasses', [
  '$resource'
  ($resource) ->
    return $resource '/sales_tax_product_classes/:id', {}, {
        query:
          method: 'GET',
          url: '/sales_tax_product_classes.json',
          isArray: true,
          cache: true
    }
]

invoiceLinesApp.controller 'InvoiceLinesController', [
  '$scope', '$log', 'SalesTaxProductClasses'
  ($scope, $log, SalesTaxProductClasses) ->

    $scope.setLines = (lines) ->
      $scope.lines = lines

    $scope.addLine = ->
      $scope.lines.push {title: "", type: "text"}

    $scope.removeLine = (line) ->
      idx = $scope.lines.indexOf(line)
      $scope.lines.splice(idx, 1)

    $scope.sales_tax_product_classes = SalesTaxProductClasses.query()

#    $scope.calc_total = (line) ->
#      net = line.amount * line.quantity
#      product_class = _.findWhere $scope.sales_tax_product_classes, (pc) ->
#        pc.id == line.sales_tax_product_class_id
#      tot = net * product_class.rate
#      return tot

    $scope.invoice_total = ->
      _.reduce $scope.lines, (memo, line) ->
        #$log.log "memo: ", memo, "line rate:", line.rate, "line qty:", line.quantity
        line_sum = 0
        if line.rate and line.quantity
          line_sum = (line.rate * line.quantity)
        memo + line_sum
      , 0

    $scope.saveLines = ->
      $('#invoice_lines').text JSON.stringify $scope.lines
      false

    true

]
