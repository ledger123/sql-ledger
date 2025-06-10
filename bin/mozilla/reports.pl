use IO::File;
use File::Temp qw(tempfile);

use SL::RP;

1;

#===============================
sub continue { &{ $form->{nextsub} } }

#=================================================
#
# Inventory Onhand Qty and Value by Based on FIFO
#
#=================================================

#-------------------------------
sub alltaxes {

    my %defaults = $form->get_defaults( $form->{dbh}, \@{ [ 'precision', 'company' ] } );
    for ( keys %defaults ) { $form->{$_} = $defaults{$_} }

    $form->{title} = $locale->text( 'All Taxes Report' . ' - ' . $form->{company} );

	$form->header;
    print qq|
    <body>
        <table width=100%>
            <tr>
                <th class="listtop">$form->{title}</th>
            </tr>
        </table>
    |;

    $form->all_departments( \%myconfig );
    if ( @{ $form->{all_department} } ) {
        $form->{selectdepartment} = "\n";
        for ( @{ $form->{all_department} } ) { $form->{selectdepartment} .= qq|$_->{description}--$_->{id}\n| }
    }

    if ( @{ $form->{all_years} } ) {

        # accounting years
        $selectaccountingyear = "\n";
        for ( @{ $form->{all_years} } ) { $selectaccountingyear .= qq|$_\n| }
        $selectaccountingmonth = "\n";
        for ( sort keys %{ $form->{all_month} } ) { $selectaccountingmonth .= qq|$_--| . $locale->text( $form->{all_month}{$_} ) . qq|\n| }

        $selectfrom = qq|
        <tr>
      <th align=right>| . $locale->text('Period') . qq|</th>
      <td colspan=3>
      <select name=month>| . $form->select_option( $selectaccountingmonth, $form->{month}, 1, 1 ) . qq|</select>
      <select name=year>| . $form->select_option( $selectaccountingyear, $form->{year}, 1 ) . qq|</select>
      <input name=interval class=radio type=radio value=0 checked>&nbsp;| . $locale->text('Current') . qq|
      <input name=interval class=radio type=radio value=1>&nbsp;| . $locale->text('Month') . qq|
      <input name=interval class=radio type=radio value=3>&nbsp;| . $locale->text('Quarter') . qq|
      <input name=interval class=radio type=radio value=12>&nbsp;| . $locale->text('Year') . qq|
      </td>
    </tr>
|;

    }

    my @columns        = qw(module account transdate invnumber description name number f amount tax);
    my @total_columns  = qw(amount tax);
    my @search_columns = qw(fromdate todate);

    my %sort_positions = {
        account        => 1,
        accdescription => 2,
        invnumber      => 3,
        transdate      => 4,
        description    => 5,
        name           => 6,
        number         => 7,
        amount         => 8,
        tax            => 9,
    };
    my $sort      = $form->{sort}  ? $form->{sort}  : 'module';
    my $sort2     = $form->{sort2} ? $form->{sort2} : 'account';
    my $sortorder = $form->{sortorder};
    my $oldsort   = $form->{oldsort};
    $sortorder = ( $sort eq $oldsort ) ? ( $sortorder eq 'asc' ? 'desc' : 'asc' ) : 'asc';

    #$form->{todate} = $form->current_date( \%myconfig ) if !$form->{todate};

    #RP->create_links(\%myconfig, \%$form, $report{$form->{reportcode}}->{vc});

    my $cashchecked;
    my $accrualchecked;
    if ( $form->{method} eq 'cash' ) {
        $cashchecked = 'checked';
    } else {
        $accrualchecked = 'checked';
    }

    if ( $form->{year} && $form->{month} ) {
        ( $form->{fromdate}, $form->{todate} ) = $form->from_to( $form->{year}, $form->{month}, $form->{interval} );
        for (qw(fromdate todate)) { $form->{$_} = $form->format_date( $myconfig{dateformat}, $form->{$_} ) }
    }
    if ( !$form->{runit} ) {

        # Defaults
        $form->{l_subtotal} = 'checked';
        $accrualchecked = 'checked';
    }

    print qq|
<form action="$form->{script}" method="post">
<table>
<tr>
    <th align=right>| . $locale->text('Department') . qq|</th>
    <td><select name=department>|
      . $form->select_option( $form->{selectdepartment}, $form->{department}, 1 ) . qq|</select>
</td>
</tr>
<tr>
    <th align="right">| . $locale->text('From date') . qq|</th>
    <td><input name=fromdate type=text size=12 class="date" value="$form->{fromdate}"></td>
</tr>
<tr>
    <th align="right">| . $locale->text('To date') . qq|</th>
    <td><input name=todate type=text size=12 class="date" value="$form->{todate}"></td>
</tr>
$selectfrom
<tr>
    <th align="right" class="norpint">| . $locale->text('Include') . qq|</th>
    <td class="noprint">|;
    for (@columns) {
        $checked = $form->{runit} ? ( $form->{"l_$_"} ? 'checked' : '' ) : 'checked';
        print qq|<input type=checkbox name=l_$_ value="1" $checked> | . ucfirst($_);
    }
    $form->hide_form(qw(nextsub path login));
    print qq|
    </td>
</tr>
<tr>
    <th align="right">| . $locale->text('Method') . qq|</th>
    <td>
        <input type=radio name=method value="accrual" $accrualchecked> Accrual
        <input type=radio name=method value="cash" $cashchecked> Cash
    </td>
</tr>

<tr>
    <th align="right">| . $locale->text('Subtotal') . qq|</th>
    <td><input type=checkbox name=l_subtotal value="checked" $form->{l_subtotal}></td>
</tr>
</table>

<hr/>
<input type=hidden name=runit value=1>
<input type=submit name=action class="submit noprint" value="Continue">
</form>
|;

    for (qw(module account)) { $form->{"l_$_"} = '' }
    my @report_columns;
    for (@columns) { push @report_columns, $_ if $form->{"l_$_"} }

    if ( !$form->{runit} ) {
        $form->{l_subtotal} = 'checked';
    }

    if ( $form->{department} ) {
        ( $form->{department_name}, $form->{department_id} ) = split /--/, $form->{department};
    }

    use SL::RP;
    my $allrows = RP->alltaxes($form);
    my @allrows = @$allrows;

    #-- Report summary starts
    if ( $form->{runit} ) {
        my %summary;
        for (@allrows) {
            $summary{ $_->{module} }{ $_->{account} }{amount} += $_->{amount};
            $summary{ $_->{module} }{ $_->{account} }{tax}    += $_->{tax};
        }

        print qq|
            <table width="100%">
                <tr class="listheading">
                <th>| . $locale->text('Module') . qq|</th>
                <th>| . $locale->text('Account') . qq|</th>
                <th>| . $locale->text('Amount') . qq|</th>
                <th>| . $locale->text('Tax') . qq|</th>
                </tr>
        |;
        for my $m (qw(AR AP GL)) {
            for my $a ( sort keys %{ $summary{$m} } ) {
                print qq|<tr class="listrow0">
                    <td>$m</td>
                    <td>$a</td>
                    <td align="right">| . $form->format_amount( \%myconfig, $summary{$m}{$a}{amount}, 2 ) . qq|</td>
                    <td align="right">| . $form->format_amount( \%myconfig, $summary{$m}{$a}{tax},    2 ) . qq|</td>
                </tr>|;
            }
        }
        print qq|</table><br/>|;

    #-- Report summary ends

    my ( %tabledata, %grandtotals, %totals, %subtotals );

    my $url = "$form->{script}?oldsort=$sort&sortorder=$sortorder";
    for (qw(action nextsub sortorder l_subtotal login path)) { $url .= "&$_=$form->{$_}" }
    for (@report_columns) { $url .= qq|&l_$_=$form->{"l_$_"}| if $form->{"l_$_"} }
    for (@search_columns) { $url .= qq|&$_=$form->{$_}|       if $form->{$_} }
    for (@report_columns) { $tabledata{$_} = qq|<th><a class="listheading" href="$url&sort=$_">| . ucfirst $_ . qq|</a></th>\n| }

    print qq|
        <table cellpadding="3" cellspacing="2" width="100%">
        <tr class="listheading">
|;
    for (@report_columns) { print $tabledata{$_} }

    print qq|
        </tr>
|;

    my $groupvalue;
    my $groupvalue2;
    my $i = 0;

    for $row (@allrows) {
        if ( !$groupvalue ) {
            $groupvalue  = $row->{account};
            $groupvalue2 = $row->{module};
            print qq|<tr class="listheading"><td colspan=8>|;
            print qq|Module: $row->{module}<br/>|;
            print qq|Account: $row->{account}<br/>|;
            print qq|</td></tr>\n|;
        }
        if ( $form->{l_subtotal} and ( $row->{account} ne $groupvalue or $row->{module} ne $groupvalue2 ) ) {
            for (@report_columns) { $tabledata{$_} = qq|<td>&nbsp;</td>| }
            $tabledata{name} = qq|<th>$groupvalue</th>|;
            for (@total_columns) { $tabledata{$_} = qq|<th align="right">| . $form->format_amount( \%myconfig, $subtotals{$_}, 2 ) . qq|</th>| }

            print qq|<tr class="listsubtotal">|;
            for (@report_columns) { print $tabledata{$_} }
            print qq|</tr>\n|;
            for (@total_columns) { $subtotals{$_} = 0 }

            if ( $groupvalue2 ne $row->{module} ) {
                for (@report_columns) { $tabledata{$_} = qq|<td>&nbsp;</td>| }
                for (@total_columns)  { $tabledata{$_} = qq|<th align="right">| . $form->format_amount( \%myconfig, $totals{$_}, 2 ) . qq|</th>| }
                print qq|<tr class="listsubtotal">|;
                for (@report_columns) { print $tabledata{$_} }
                print qq|</tr>\n|;
                for (@total_columns) { $totals{$_} = 0 }
            }
            print qq|<tr>|;
            for (@report_columns) { print qq|<td>&nbsp;</td>| }
            print qq|</tr>\n|;

            print qq|<tr class="listheading"><td colspan=8>|;
            print qq|Module: $row->{module}<br/>|;
            print qq|Account: $row->{account}<br/>|;
            print qq|</td></tr>\n|;
        }
        $groupvalue  = $row->{account};
        $groupvalue2 = $row->{module};

        for (@report_columns) { $tabledata{$_} = qq|<td>$row->{$_}</td>| }

        $invnumber = qq|<a href="$row->{script}?id=$row->{id}&action=edit&path=$form->{path}&login=$form->{login}" target="_blank">$row->{invnumber}</a>|;
        $tabledata{invnumber} = qq|<td>$invnumber</td>|;

        $db = ( $row->{module} eq 'AR' ) ? 'customer' : 'vendor';
        $db = '' if $row->{module} eq 'GL';

        if ($db) {
            $vc = qq|<a href="ct.pl?id=$row->{vc_id}&db=$db&action=edit&path=$form->{path}&login=$form->{login}" target="_blank">$row->{name}</a>|;
            $tabledata{name} = qq|<td>$vc</td>|;
        }

        for (@total_columns) { $tabledata{$_} = qq|<td align="right">| . $form->format_amount( \%myconfig, $row->{$_}, 2 ) . qq|</td>| }
        for (@total_columns) { $totals{$_}      += $row->{$_} }
        for (@total_columns) { $subtotals{$_}   += $row->{$_} }
        for (@total_columns) { $grandtotals{$_} += $row->{$_} }

        print qq|<tr class="listrow$i">|;
        for (@report_columns) { print $tabledata{$_} }
        print qq|</tr>\n|;
        $i += 1;
        $i %= 2;
    }

    for (@report_columns) { $tabledata{$_} = qq|<td>&nbsp;</td>| }
    $tabledata{name} = qq|<th>$groupvalue</th>|;
    for (@total_columns) { $tabledata{$_} = qq|<th align="right">| . $form->format_amount( \%myconfig, $subtotals{$_}, 2 ) . qq|</th>| }

    print qq|<tr class="listsubtotal">|;
    for (@report_columns) { print $tabledata{$_} }
    print qq|</tr>\n|;

    for (@report_columns) { $tabledata{$_} = qq|<td>&nbsp;</td>| }
    for (@total_columns)  { $tabledata{$_} = qq|<th align="right">| . $form->format_amount( \%myconfig, $totals{$_}, 2 ) . qq|</th>| }
    print qq|<tr class="listtotal">|;
    for (@report_columns) { print $tabledata{$_} }
    print qq|</tr>|;

    for (@total_columns) { $tabledata{$_} = qq|<th align="right">| . $form->format_amount( \%myconfig, $grandtotals{$_}, 2 ) . qq|</th>| }
    print qq|<tr class="listtotal">|;
    for (@report_columns) { print $tabledata{$_} }
    print qq|</tr>
</table>
|;
    }

    print qq|
</body>
</html>|;

}


