[%# Part of Pulma standard templates

    Copyright (C) 2011 Fedor A. Fetisov <faf@ossg.ru>. All Rights Reserved

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
-%]
<!doctype html>
<html lang="[% GET pulma.locale %]">
    <head>
	<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
	<meta charset="UTF-8">
	<title>[% GET pulma.data.error.code %] [% GET pulma.data.error.title %]</title>
    </head>
    <body>
	<h1>[% GET pulma.data.error.title %]</h1>
	<p>[% GET pulma.data.error.text %]</p>
    </body>
</html>
