$(document).ready(function() {
    $('.estados').select2({
        allowClear: true
    });

    $(window).resize(function() {
        removeplot();
        addplot($( "#estados option:selected" ).text(), margin, padding, ydomain);
    });

    addplot("Ciudad de México", margin, padding, ydomain);

    $('#estados').on('select2:select', function (e) {
        removeplot()
        addplot($( "#estados option:selected" ).text(), margin, padding, ydomain);
    });


});