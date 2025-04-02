jQuery(document).ready(function() {
  jQuery(document).on('ajax:beforeSend', '.batch-create-rows a', function(event, xhr, settings) {
    var num_records = jQuery(this).closest('.batch-create-rows').find('input[name=num_records]').val();
    if (num_records) settings.url += (settings.url.indexOf('?') != -1 ? '&' : '?') + 'num_records=' + num_records;
    return true;
  });
  jQuery(document).on('click', '.multiple .form_record a.remove', function(event) {
    event.preventDefault();
    var record = jQuery(this).closest('.form_record');
    record.prev('.form_record-errors').remove();
    record.remove();
  });
  jQuery(document).on('change', 'select.as_update_date_operator, select.as_batch_update_operator', function(event) {
    ActiveScaffold[jQuery(this).val() === 'REPLACE' ? 'show' : 'hide'](jQuery(this).next());
  });
  jQuery(document).on('change', 'select.as_update_date_operator', function(event) {
    ActiveScaffold[['REPLACE', 'NO_UPDATE', 'NULL'].indexOf(jQuery(this).val()) !== -1 ? 'hide' : 'show'](jQuery(this).next().next());
  });
});
