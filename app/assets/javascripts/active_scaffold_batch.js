jQuery(document).ready(function() {
  jQuery(document).on('ajax:beforeSend', '.batch-create-rows a', function(event, xhr, settings) {
    var num_records = jQuery(this).closest('.batch-create-rows').find('input[name=num_records]').val();
    if (num_records) settings.url += (settings.url.indexOf('?') != -1 ? '&' : '?') + 'num_records=' + num_records;
    return true;
  });
  jQuery(document).on('change', '.as_update_date_operator, .as_batch_update_operator, .as_update_numeric_option', function(event) {
    var $op = jQuery(this), method,
      fields = $op.closest('.form-element').find(':input, .mceEditor + div').not(this).filter(function() {
        return jQuery(this).closest('.search-date-trend').length === 0;
      });
    if ($op.is('.as_update_date_operator')) method = $op.val() === 'REPLACE' ? 'show' : 'hide';
    else method = ['NO_UPDATE', 'NULL'].indexOf(jQuery(this).val()) !== -1 ? 'hide' : 'show';
    ActiveScaffold[method](fields);
  });
  jQuery(document).on('change', '.as_update_date_operator', function(event) {
    ActiveScaffold[['REPLACE', 'NO_UPDATE', 'NULL'].indexOf(jQuery(this).val()) !== -1 ? 'hide' : 'show'](jQuery(this).closest('.form-element').find('.search-date-trend'));
  });
});
