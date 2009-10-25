$(function () {
  $('a.delete').click(function() {
    if(confirm('Are you sure?')) {
      $.post(this.href, { openid: $('input').val() } );
      window.location.replace('/');
    }
    return false;
    });
});
