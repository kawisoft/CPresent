Presenter = angular.module 'Presenter', ['ui.directives','ngResource','ngSanitize']

Presenter.directive 'colorpicker', ->
	require: '?ngModel'
	link: (scope, element, attrs, controller) ->
		if controller?
			updateModel = (value) ->
				scope.$apply ->
					controller.$setViewValue value

			controller.$render = ->
				color =  new jscolor.color $ element
				$(element).on 'change', (e) ->
					if updateModel?
						updateModel e.target.value
				color

		color =  new jscolor.color element
		$(element).on 'change', (e) ->
			if updateModel? then updateModel e.target.value
		color


Presenter.factory 'Songs', ['$resource','$http','$rootScope', (resource, $http,$rootScope) ->
	song = resource '/songs/:id',
		id:'@_id'
	getAll: ->
		song.query()
	get: (id,callback) ->
		song.get
			id:id
		,callback
	edit: (song) ->
		song.$update()
	create: (song,callback) ->
		$http.put('/songs',song)
	remove: (song) ->
		song.$remove()
]

Presenter.factory 'Server', ->
	socket = io.connect()
	goLive: (lyric, slideBgC, slideTxtC, slideH, slideV) ->
		socket.emit 'go:live',
			text: lyric
			bg: slideBgC
			color: slideTxtC
			h: slideH
			v: slideV
	toggleLive: (bool) ->
		socket.emit 'toggle:live', {stat:bool}
	goBlack: (bool) ->
		socket.emit "go:black", {stat: bool}
	goClear: (bool) ->
		socket.emit "go:clear", {stat:bool}
	changeSlide: (lyric) ->
		socket.emit "next:slide", {lyric:lyric}
	_socket: socket

PresentationManagerController = ['$scope','Songs','Server', ($scope,Songs,io2) ->
	$scope.songlist = Songs.getAll()
	$scope.setlist = []
	$scope.lyrics = []
	$scope.slideV = "mid"
	$scope.slideH = "cen"
	$scope.prevLyrics = []
	$scope.isLive = false
	$scope.live = '#fff'
	$scope.tester = ""
	$scope.callLive = ->
		$scope.live = $scope.isLive ? '#33B5E5' : '#ffffff'
		io2.toggleLive $scope.isLive

	socket = io.connect()
	socket.on 'connect', ->
		socket.on 'set:setlist', (data) ->
			$scope.setlist = data
			$scope.$watch 'setlist', (n,o) ->
				socket.emit 'set:setlist', $scope.setlist
			, true
			$scope.$digest()
		socket.emit 'get:setlist', {}
		socket.on 'toggle:live', (data) ->
			$scope.isLive = data.stat
		socket.on 'go:black', (data) ->
			$scope.black = data.stat
]

SongListController = ['$scope','Songs', ($scope,Songs) ->
	$scope.delDisp = {display:'none'}

	$scope.addToSetList = (song) ->
		# For some reason you have to create a new array instead of manipulating the old one.
		newArray = new Array()
		newArray = $scope.setlist
		newArray.push Songs.get song._id
		$scope.$parent.setlist = newArray

	$scope.shDelete = (element) ->
		$scope.delDisp = if $scope.search isnt "" then {display:'block'} else {display:'none'}

	$scope.focused = (ami) ->
		$scope.focus = ami? 'focused' : ''

	$scope.hover = (ami) ->
		$scope.hoverd = ami? 'hovered' : ''

	$scope.editSong = (song) ->
		newsong = Songs.get song._id, ->
			$scope.tester = newsong
			$scope.songEdit = true
			$scope.isNew = false

	$scope.saveSong = (song,n) ->
		Songs.edit(song) if !n else Songs.create song
		$scope.$parent.songlist = Songs.getAll()
		$scope.songEdit = false

	$scope.songDelete = (song) ->
		Songs.remove(song)
		$scope.songEdit = false
		$scope.$parent.songlist = Songs.getAll()
]

SetListController = ($scope) ->
	$scope.removeFromSetList = (index) ->
		newArray = new Array()
		newArray = $scope.setlist
		newArray.splice(index,1)
		$scope.setlist= newArray

	$scope.showLyrics = (song) ->
		if !song.lyrics? then return false
		song.lyrics += "\n\n"
		lyrics = song.lyrics.match /^([\s\S]*?)(?=\n\n|$\w)/gim
		$scope.lyrics.splice 0
		for lyric in lyrics
			reg = /(?:\n)*((?:Verse [0-9]|Chorus(?:| [0-9])|Tag|Bridge|Pre-Chorus)\n)*([\s\S]*)/gim
			matcher = reg.exec lyric
			$scope.lyrics.push
				tag: if matcher[1]? then matcher[1] else ""
				para:matcher[2].replace /\n/gim, "<br />"
		$scope.$parent.preview  = lyrics[0].para

SlideController = ['$scope','Server', ($scope, io) ->
	$('#cp').colorpicker({format:'hex'}).on 'changeColor', (ev) ->
		$scope.$apply ->
			$scope.$parent.slideBgC = ev.color.toHex()

	$('#cp2').colorpicker({format:'hex'}).on 'changeColor', (ev) ->
		$scope.$apply ->
			$scope.$parent.slideTxtC = ev.color.toHex()

	$scope.$parent.slideBgC = "#ffffff"
	$scope.$parent.slideTxtC = "#000000"
	$scope.loadLyric = (lyric) ->
		$scope.$parent.preview  = lyric.para

	$scope.alignH = (align) ->
		$scope.$parent.slideH = align

	$scope.alignV = (align) ->
		$scope.$parent.slideV = align
	
	$scope.updateSlideBgC = (value) ->
		console.log(value)

	$("#slider").on 'change', ->
		$scope.$parent.$digest()

	$scope.goLive = (lyrics) ->
		$scope.$parent.prevH = $scope.$parent.slideH
		$scope.$parent.prevV = $scope.$parent.slideV
		$scope.$parent.preview2 = $scope.$parent.preview
		$scope.$parent.prevTxtC = $scope.$parent.slideTxtC
		$scope.$parent.prevBgC = $scope.$parent.slideBgC
		$scope.$parent.black = "#000"
		$scope.prevLyrics.splice 0
		$scope.prevLyrics.push lyric for lyric in lyrics
		$scope.$parent.isLive = true
		$scope.$parent.callLive()
		io.goLive $scope.$parent.preview, $scope.$parent.prevBgC, $scope.$parent.prevTxtC, $scope.$parent.slideH, $scope.$parent.slideV
]

LiveController = ['$scope','Server', ($scope,io) ->
	$scope.$parent.black = false
	$scope.clear = false
	io._socket.on 'go:clear', (data) ->
		$scope.clear = data.stat
	$scope.loadLyric = (lyric) ->
		$scope.$parent.preview2  = lyric.para
		io.changeSlide(lyric.para)

	$scope.toggleBlack = ->

		$scope.clear = $scope.$parent.black = !$scope.$parent.black
		io.goBlack $scope.$parent.black

	$scope.toggleClear = ->
		$scope.clear = !$scope.clear
		io.goClear $scope.clear
]
