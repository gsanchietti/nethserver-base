<?php
/* @var $view \Nethgui\Renderer\Xhtml */
echo $view->header()->setAttribute('template', $T('Pki_Title'));

$view->requireFlag($view::INSET_DIALOG);

echo $view->textLabel('name');

echo $view->buttonList()
    ->insert($view->button('Generate', $view::BUTTON_SUBMIT))
    ->insert($view->button('Cancel', $view::BUTTON_CANCEL))
;
