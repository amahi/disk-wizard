// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.
$(document).ready(function () {

    $('.aleart_box > .alert').hide();
    $('.aleart_box > .alert').fadeIn(1500, function () {
        $(this).delay(6000).fadeOut(1000, function () {
        });
    });
    $('input.format').on('change', function () {
        $('input.format').not(this).prop('checked', false);
        var rows = $('tr:not(:first) td:not(:last-child)');

        var row = $(this).closest('tr');

        if (row.hasClass("warning")) {
            rows.closest('tr').removeClass('info');
            row.addClass('danger');
        } else {
            rows.closest('tr').removeClass('danger');
            rows.closest('tr').removeClass('info');
            row.addClass('info');
        }
        $('input.format').not(this).prop('checked', false);
        $("#proceed").html("Next");
        var path = row.attr("path");
        $("#partition").attr("value", path);

    });
    $(function () {
        //TODO: Tempory fix for bootstrap theme styles conflict
        $('#preferences').removeClass()
    });
});
