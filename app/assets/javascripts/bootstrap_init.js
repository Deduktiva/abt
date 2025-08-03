// Simple dropdown and alert functionality using jQuery (since Bootstrap 5 might not be fully loaded)
$(document).ready(function() {
  // Handle dropdown toggle clicks
  $('.dropdown-toggle').on('click', function(e) {
    e.preventDefault();
    var $dropdown = $(this).next('.dropdown-menu');

    // Close all other dropdowns
    $('.dropdown-menu').not($dropdown).removeClass('show');

    // Toggle this dropdown
    $dropdown.toggleClass('show');
  });

  // Close dropdown when clicking outside
  $(document).on('click', function(e) {
    if (!$(e.target).closest('.dropdown').length) {
      $('.dropdown-menu').removeClass('show');
    }
  });

  // Handle alert close buttons
  $('.btn-close').on('click', function() {
    $(this).closest('.alert').fadeOut();
  });
});
