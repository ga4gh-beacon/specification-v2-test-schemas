
<div id="schema-header-title">
  <h2>BiosampleResponseContent <span id="schema-header-title-project">beacon-v2 <a href="https://github.com/ga4gh-beacon/specification-v2-blocks" target="_BLANK">&nearr;</a></span> </h2>
</div>

<table id="schema-header-table">
  <tr>
    <th>{S}[B] Status <a href="https://schemablocks.org/about/sb-status-levels.html">[i]</a></th>
    <td><div id="schema-header-status">community</div></td>
  </tr>

  <tr>
    <th>Provenance</th>
    <td>
      <ul>
<li><a href="https://github.com/ga4gh-beacon/specification-v2"></a></li>
<li><a href="https://github.com/progenetix/bycon/"></a></li>
      </ul>
    </td>
  </tr>
  <tr>
    <th>Used by</th>
    <td>
      <ul>
<li><a href="https://github.com/progenetix/schemas/"></a></li>
      </ul>
    </td>
  </tr>

<!--more-->

  <tr>
    <th>Contributors</th>
    <td>
      <ul>
<li><a href="https://beacon-project.io/categories/people.html"></a></li>
<li><a href="https://github.com/jrambla"></a></li>
<li><a href="https://github.com/sdelatorrep"></a></li>
<li><a href="https://github.com/mamanambiya"></a></li>
<li><a href="https://orcid.org/0000-0002-9903-4248"></a></li>
      </ul>
    </td>
  </tr>
  <tr>
    <th>Source (2.0.0-draft.3)</th>
    <td>
      <ul>
        <li><a href="current/BiosampleResponseContent.json" target="_BLANK">raw source [JSON]</a></li>
        <li><a href="https://github.com/ga4gh-beacon/specification-v2-blocks/blob/master/schemas/BiosampleResponseContent.yaml" target="_BLANK">Github</a></li>
      </ul>
    </td>
  </tr>
</table>

<div id="schema-attributes-title">
  <h3>Attributes</h3>
</div>

  
__Type:__ object  
__Description:__ Description pending

### Properties

<table id="schema-properties-table">
  <tr>
    <th>Property</th>
    <th>Type</th>
  </tr>
  <tr>
    <th>beaconHandover</th>
    <td>array of "./Handover"</td>
  </tr>
  <tr>
    <th>error</th>
    <td>BeaconError</td>
  </tr>
  <tr>
    <th>exists</th>
    <td>boolean</td>
  </tr>
  <tr>
    <th>info</th>
    <td>object</td>
  </tr>
  <tr>
    <th>numTotalResults</th>
    <td>integer</td>
  </tr>
  <tr>
    <th>results</th>
    <td>array of "./BiosampleResponseResults"</td>
  </tr>
  <tr>
    <th>resultsHandover</th>
    <td>array of "./Handover"</td>
  </tr>

</table>


#### beaconHandover

* type: array of "./Handover"




#### error

* type: BeaconError




#### exists

* type: boolean

Indicator of whether any biosample was observed in any of the
datasets queried. This should be non-null, unless there was an
error, in which case `error` has to be non-null.



#### info

* type: object




#### numTotalResults

* type: integer




#### results

* type: array of "./BiosampleResponseResults"




#### resultsHandover

* type: array of "./Handover"



