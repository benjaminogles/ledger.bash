
const state = {}
var isource = -1
var isink = -1
var register = ''
var source_selected = false

const isdigit = (key) => parseInt(key) >= 0 && parseInt(key) <= 9

const table = () => document.querySelector('#accounts').querySelector('tbody')
const bottom = () => document.querySelector('#new-account')
const submit = () => document.querySelector('#new-account-submit')
const input = () => document.querySelector('#new-account-name')
const output = () => document.querySelector('#export')
const rows = () => Array.from(table().querySelectorAll('tr')).filter(tr => tr.id != 'new-account')
const row = (i) => rows()[i]

const find_row = (account) => {
  let i = 0
  for (let tr of rows()) {
    if (tr.firstChild.textContent === account)
      return i
    else
      i++
  }
  return -1
}

const wrap = (i, orig, avoid) => {
  const nrows = rows().length
  let want = i
  if (want >= nrows)
    want = 0
  else if (want < 0)
    want = nrows - 1
  if (want !== avoid)
    return want
  if (i > orig && want + 1 < nrows)
    return want + 1
  else if (i < orig && want - 1 >= 0)
    return want - 1
  else if (i < orig && nrows - 1 >= 0 && nrows - 1 !== avoid)
    return nrows - 1
  else if (i > orig && 0 < nrows && 0 !== avoid)
    return 0
  console.warn('wrap error')
  return want
}

const make_account = (name, amount) => {
  const account = name.trim()
  if (account.length === 0 || account in state)
    return

  state[account] = amount

  const container = document.createElement('tr')
  const label = document.createElement('td')
  const value = document.createElement('td')
  label.appendChild(document.createTextNode(account))
  value.appendChild(document.createTextNode(amount.toString()))
  container.appendChild(label)
  container.appendChild(value)

  table().insertBefore(container, bottom())
  input().value = ''
}

const set_source = (i) => {
  if (isource >= 0)
    row(isource).classList.remove('source')
  row(i).classList.remove('sink')
  row(i).classList.add('source')
  isource = i
}

const set_sink = (i) => {
  if (isink >= 0)
    row(isink).classList.remove('sink')
  row(i).classList.remove('source')
  row(i).classList.add('sink')
  isink = i
}

const get_account = (i) => {
  return parseFloat(row(i).childNodes[1].textContent)
}

const set_account = (i, amount) => {
  const account = row(i).firstChild.textContent.trim()
  if (account in state)
    state[account] = amount
  else
    console.warn('set_account error')
  row(i).childNodes[1].innerHTML = amount.toString()
}

const transfer = (from, to, after_deposit) => {
  if (from < 0 || to < 0 || isNaN(after_deposit))
    return
  const before_withdrawal = get_account(from)
  const before_deposit = get_account(to)
  const adjust = Math.abs(after_deposit - before_deposit)
  const after_withdrawal = after_deposit > before_deposit ? (before_withdrawal - adjust) : (before_withdrawal + adjust)
  set_account(to, after_deposit.toFixed(2))
  set_account(from, after_withdrawal.toFixed(2))
}

const set_register = (s) => {
  register = s
  document.querySelector('#register').innerHTML = s
}

const output_header = () => {
  const d = new Date()
  const year = d.getFullYear().toString()
  const month = (d.getMonth() + 1).toString().padStart(2, '0')
  const day = d.getDate().toString().padStart(2, '0')
  return year + '/' + month + '/' + day + ' Budget'
}

const refresh_output = () => {
  output().value = ''
  const changes = {}

  for (var account in state) {
    if (account in accounts)
      changes[account] = state[account] - accounts[account]
    else
      changes[account] = state[account]
  }

  output().value += output_header() + '\n'
  for (var account in changes) {
    if (changes[account] == 0)
      continue

    let record = '    [' + account + ']  '
    if (changes[account] < 0) {
      changes[account] *= -1
      record += '-'
    }
    record += '$' + changes[account].toFixed(2).toString() + '\n'

    output().value += record
  }
}

const refresh_scroll = () => {
  if (source_selected && isource > 0)
    row(isource).scrollIntoView(true)
  else if (isink > 0)
    row(isink).scrollIntoView(true)
}

const advance_state = (e) => {
  if (e.key == 'j') {
    set_register('')
    if (source_selected)
      set_source(wrap(isource + 1, isource, isink))
    else
      set_sink(wrap(isink + 1, isink, isource))
  }
  else if (e.key == 'k') {
    set_register('')
    if (source_selected)
      set_source(wrap(isource - 1, isource, isink))
    else
      set_sink(wrap(isink - 1, isink, isource))
  }
  else if (e.key == 'Enter') {
    transfer(isource, isink, parseFloat(register))
    set_register('')
    refresh_output()
  }
  else if (e.key == ' ')
    source_selected = !source_selected
  else if (e.key == '-') {
    if (register.length === 0)
      set_register('-')
  }
  else if (e.key == '.') {
    if(register.indexOf('.') < 0)
      set_register(register + '.')
  } else if (e.key == 'Backspace')
    set_register(register.substr(0, register.length - 1))
  else if (isdigit(e.key))
    set_register(register + e.key)
  refresh_scroll()
}

const select_account = (e) => {
  let target = e.target
  if (target && target.tagName == 'TD')
    target = target.parentElement
  if (target && target.tagName == 'TR') {
    const i = find_row(target.firstChild.textContent)
    if (i < 0 || i >= rows().length)
      return
    if (source_selected)
      set_source(i)
    else
      set_sink(i)
    refresh_scroll()
  }
}

window.onload = (e) => {
  submit().onclick = _ => make_account(input().value, 0)
  document.onkeyup = advance_state
  document.onclick = select_account
  for (account in accounts)
    make_account(account, accounts[account])
  const isource_default = find_row('Budget:Unbudgeted')
  if (isource_default >= 0)
    set_source(isource_default)
}

