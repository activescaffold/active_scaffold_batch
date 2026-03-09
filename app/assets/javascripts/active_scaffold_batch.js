jQuery(document).ready(function() {
  jQuery(document).on('ajax:beforeSend', '.batch-create-rows a', function(event, xhr, settings) {
    var num_records = jQuery(this).closest('.batch-create-rows').find('input[name=num_records]').val();
    if (num_records) settings.url += (settings.url.indexOf('?') != -1 ? '&' : '?') + 'num_records=' + num_records;
    return true;
  });
  jQuery(document).on('change', 'select.as_update_date_operator, select.as_batch_update_operator', function(event) {
    var fields = jQuery(this).closest('.form-element').find(':input, .mceEditor + div').not(this).filter(function() {
      return jQuery(this).closest('.search-date-trend').length === 0;
    });
    ActiveScaffold[jQuery(this).val() === 'REPLACE' ? 'show' : 'hide'](fields);
  });
  jQuery(document).on('change', '.as_update_date_operator', function(event) {
    ActiveScaffold[['REPLACE', 'NO_UPDATE', 'NULL'].indexOf(jQuery(this).val()) !== -1 ? 'hide' : 'show'](jQuery(this).closest('.form-element').find('.search-date-trend'));
  });
});
