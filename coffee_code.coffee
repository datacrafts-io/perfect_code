class @ReminderTemplate
  @TEMPLATE_SELECTOR             = '.reminder-template-preview'
  TEMPLATE_LOADER_SELECTOR       = '.reminder-template-loader'
  TEMPLATE_EDIT_ON_BTN_SELECTOR  = '.reminder-edit-on-btn'
  TEMPLATE_EDIT_OFF_BTN_SELECTOR = '.reminder-edit-off-btn'
  TEMPLATE_LANG_SELECT_SELECTOR  = '.reminder-edit-lang'
  TEMPLATE_MESSAGE_SELECTOR      = '.reminder-template-message'
  EDITABLE_CLASS_PATTERN         = 'edit-reminder-'
  EDITABLE_FIELD_CLASS           = 'reminder-editable-field'

  constructor: ($template, lipscoreInitialized = false) ->
    @$template     = $template
    @$loader       = @$template.find(TEMPLATE_LOADER_SELECTOR)
    @$editOnBtn    = @$template.find(TEMPLATE_EDIT_ON_BTN_SELECTOR)
    @$editOffBtn   = @$template.find(TEMPLATE_EDIT_OFF_BTN_SELECTOR)
    @$templateLang = @$template.find(TEMPLATE_LANG_SELECT_SELECTOR)
    @$alertView    = @$template.find(TEMPLATE_MESSAGE_SELECTOR)

    @showLoader()
    @initControls()

    $(document).on 'lipscore-created', =>
      @finishInitialization()

    if lipscoreInitialized
      @finishInitialization()

  hideLoader: ->
    @$loader.addClass('hidden')

  showLoader: ->
    @$loader.removeClass('hidden')

  showEditOnBtn: ->
    @$editOnBtn.removeClass('hidden')

  hideEditOnBtn: ->
    @$editOnBtn.addClass('hidden')

  showEditOffBtn: ->
    @$editOffBtn.removeClass('hidden')

  hideEditOffBtn: ->
    @$editOffBtn.addClass('hidden')

  initControls: ->
    instance = @

    @$templateLang.editable
      showbuttons: false
      unsavedclass: null
      autotext: 'always'
      select2:
        minimumResultsForSearch: -1
        dropdownAutoWidth: true
      success: (data, newValue) =>
        @loadTemplate(newValue)

    @editableElements().each ->
      $(@).data('place', 'email')

  addHandlers: ->
    instance = @

    @$editOnBtn.on 'click', (e) ->
      e.preventDefault()

      instance.editableElements().each ->
        $source = $(@)
        $ediatbelFeild = instance.createEditableField($source)
        instance.initEditableField($ediatbelFeild, $source)

      instance.hideEditOnBtn()
      instance.showEditOffBtn()

    @$editOffBtn.on 'click', (e) ->
      e.preventDefault()
      instance.loadTemplate()

  editableElements: ->
    @$template.find('[class*="' + EDITABLE_CLASS_PATTERN + '"]')

  createEditableField: ($source) ->
    if $source.is('a')
      $link = $source.clone(false)
      $link.removeClass()
    else
      $link = $('<a></a>')
      $link.addClass('reminder-editable-link-styled')

    key   = @getKey($source)
    text  = @getText($source)
    place = $source.data('place')

    $link.addClass(EDITABLE_FIELD_CLASS)
    $link.attr('href', '#')
    $link.data('value', text)
    $link.data('url', @getTextUrl($source))
    $link.text(text)

    $source.hide()
    $source.after($link)

    if key.match((/header$/))
      $link.after('<br>')

    if place == 'landing'
      $link.attr('class', $source.attr('class'))
      $link.css('color', $source.css('color'))
      $link.css('display', 'inline-block')

    $link

  initEditableField: ($field, $source) ->
    instance  = @
    lang      = @getTemplateLang()
    key       = @getKey($source)
    emptyText = @getEmptyText()
    textType  = "#{$source.data('place')}_text"

    $field.editable
      name: "#{textType}[text]"
      ajaxOptions:
        type: 'post'
      params: (params) ->
        params["#{textType}[lang]"] = lang
        params["#{textType}[key]"]  = key
        params
      emptytext: emptyText
      type: 'textarea'
      mode: 'popup'
      placement: 'bottom'
      showbuttons: 'bottom'
      pk: 0
      inputclass: 'reminder-editable-text'

    $field.on 'shown', (e, editable) ->
      instance.addResetBtn(editable.container.$form, $source, editable.$element)
      instance.autoSizeText(editable.input.$input)

  loadTemplate: (lang) ->
    alertView = new AlertView(@$alertView)
    lang      = @getTemplateLang() unless lang?
    url       = @getTemplateUrl()

    $.ajax
      url: url
      dataType: 'html'
      data:
        lang: lang
      beforeSend: =>
        @showLoader()
      success: (content) =>
        $newTemplate = $(content)
        @$template.replaceWith($newTemplate)
        new ReminderTemplate($newTemplate, true)
      error: (xhr) ->
        alertView.showError(xhr.status)

  finishInitialization: ->
    new LandingPreview(@$template, EDITABLE_CLASS_PATTERN)
    @addHandlers()
    @hideLoader()

  getKey: ($source) ->
    key = $source.data('key')

    unless key?
      classes = $source.attr('class').split(' ')
      keyClasses = (c for c in classes when c.indexOf(EDITABLE_CLASS_PATTERN) != -1)
      key = keyClasses[0].replace(EDITABLE_CLASS_PATTERN, '').replace(/-/g, '_')
      $source.data('key', key)
    key

  getText: ($source) ->
    key   = @getKey($source)
    place = $source.data('place')

    @$template.data("#{place}Texts")[key]

  getTextUrl: ($source) ->
    place = $source.data('place')
    @$template.data("#{place}TextUrl")

  getTemplateUrl: ->
    @$template.data('templateUrl')

  getTemplateLang: ->
    @$templateLang.editable('getValue', true)

  getDefault: ($source) ->
    key   = @getKey($source)
    place = $source.data('place')

    @$template.data("#{place}Defaults")[key]

  getEmptyText: ->
    @$template.data('emptyText')

  getResetText: ->
    @$template.data('resetText')

  addResetBtn: ($form, $source, $editableField) ->
    $btn = $(
      """
      <a href="#" class="reminder-text-reset-btn">
        Reset to default
      </a>
      """
    )
    $form.find('.editable-buttons').append($btn)
    $btn.on 'click', (e) =>
      e.preventDefault()

      if confirm? @getResetText()
        $editableField.editable('hide')

        key  = @getKey($source)
        lang = @getTemplateLang()

        $.ajax
          url: "#{@getTextUrl($source)}/#{key}"
          data:
            lang: lang
          type: 'DELETE'
          success: =>
            defaultText = @getDefault($source)
            if defaultText?
              $editableField.editable('setValue', defaultText)
            else
              $editableField.editable('setValue', null)
              $editableField.text(@getEmptyText())
              $editableField.addClass('editable-empty')

  autoSizeText: ($el) ->
    if $el[0].scrollHeight > 0
      $el.textareaAutoSize().trigger('input')
    else
      instance = @

      setTimeout(
        -> instance.autoSizeText($el),
        0
      )

$ ->
  $(ReminderTemplate.TEMPLATE_SELECTOR).each ->
    new ReminderTemplate($(@))
