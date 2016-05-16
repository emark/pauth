<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <!-- The above 3 meta tags *must* come first in the head; any other head content must come *after* these tags -->
    <meta name="description" content="">
    <meta name="author" content="">
    <link rel="icon" href="">

    <title>Регистрация подключения</title>

    <!-- Bootstrap core CSS -->
    <link href="/public/bootstrap/dist/css/bootstrap.min.css" rel="stylesheet">

    <!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
    <link href="/public/bootstrap/assets/css/ie10-viewport-bug-workaround.css" rel="stylesheet">

    <!-- Custom styles for this template -->
    <link href="/public/bootstrap/examples/sticky-footer/sticky-footer.css" rel="stylesheet">

    <!-- Just for debugging purposes. Don't actually copy these 2 lines! -->
    <!--[if lt IE 9]><script src="/public/bootstrap/assets/js/ie8-responsive-file-warning.js"></script><![endif]-->
    <script src="/public/bootstrap/assets/js/ie-emulation-modes-warning.js"></script>

    <!-- HTML5 shim and Respond.js for IE8 support of HTML5 elements and media queries -->
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
    <![endif]-->
  </head>

  <body>

    <!-- Begin page content -->
    <div class="container">
      <div class="page-header">
	      <div class="center-block"><img src="/public/bootstrap/assets/img/free-wifi.png" class="img-responsive"></div>
        <h1>Регистрация подключения к сети интернет</h1>
      </div>
    
    	<p class="well"><TMPL_VAR NAME="msg"></p>
		
    	<form action="" method="post">
  		
  		<div class="form-group">
  			<label for="InputCode">Код регистрации</label>
  			
  			<div class="row">
					<div class="col-sm-3 col-xs-6">
	  			<input type="number" class="form-control input-lg" id="InputCode" placeholder="" name="code" value="">
	  			</div>
	  		</div>
	  		
  		</div>
  		
  		<button type="submit" class="btn btn-default btn-lg">Далее</button>
  		<input type="hidden" name="phone" value="<TMPL_VAR NAME="phone">">
			</form>
			&nbsp;
			
    </div>
    
    <footer class="footer">
      <div class="container">
        <p class="text-muted">Гостиница &laquo;Три медведя&raquo;, Красноярск</p>
      </div>
    </footer>


    <!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
    <script src="/public/bootstrap/assets/js/ie10-viewport-bug-workaround.js"></script>
  </body>
</html>

