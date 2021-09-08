import { Grid, Navbar } from "react-bootstrap";
import atarefado from './images/atarefado.png';

import 'bootstrap/dist/css/bootstrap.min.css';
import './App.css';

function App() {
  return (<>
    <Navbar fixedTop inverse fluid>
      <Navbar.Header>
        <Navbar.Brand>
          <a href="/">
            <img src={atarefado} width="32" height="32" alt="" />
            <span class="hidden-xs"> Atarefado {process.env.REACT_APP_VERSION}</span>
          </a>
        </Navbar.Brand>
      </Navbar.Header>
    </Navbar>
    <Grid>
      <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras placerat laoreet tempor. Duis quis lacus dolor. Proin feugiat facilisis tellus tristique aliquet. Sed eu hendrerit nunc. Maecenas ultrices imperdiet tellus in placerat. Aliquam erat volutpat. Sed sit amet purus elit. Integer posuere porttitor mi nec blandit. Praesent sodales leo a ligula bibendum vehicula. Donec sit amet massa commodo, efficitur libero eget, hendrerit sapien. Mauris vel condimentum erat. Nunc convallis neque lectus, quis faucibus elit consectetur vel. Sed ligula enim, pharetra ac ante et, rutrum tristique lacus. Aliquam erat volutpat. Vestibulum facilisis elementum erat, nec convallis orci iaculis in. Curabitur ut tempus libero.</p>
      <p>Vivamus id tempor turpis. Ut malesuada purus ante, sed suscipit dui rhoncus non. Quisque eleifend ultricies ante, sed lacinia sem malesuada et. Aliquam suscipit arcu est, quis congue eros tempor quis. Mauris nunc magna, lobortis fermentum felis quis, dapibus feugiat lacus. Donec cursus tortor velit, et eleifend nisl commodo sed. Morbi dui sapien, rutrum in vestibulum eget, volutpat quis augue. Nunc vitae turpis sed erat feugiat iaculis ut id libero. Maecenas sagittis tortor sit amet augue consequat lobortis. Duis suscipit fermentum massa, a volutpat justo tincidunt ac.</p>
      <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Praesent lobortis pretium lacus, non consequat nisi efficitur sed. Phasellus ultricies suscipit mi sed mollis. Mauris massa lacus, lobortis a blandit vel, mollis vel massa. Integer malesuada erat at imperdiet vehicula. Cras imperdiet nunc sed dui volutpat, ac tempor urna tempor. Nunc gravida lacus nec sapien pharetra sagittis. Donec sit amet convallis quam. Ut congue scelerisque leo, eu tristique massa pharetra ac. Proin vulputate, urna eu aliquam accumsan, nisi erat feugiat elit, ut malesuada dui mauris vitae neque. Quisque bibendum sollicitudin eros vel luctus. Integer fringilla sed neque dictum congue. Quisque id risus accumsan, commodo purus sit amet, pulvinar lacus. Donec quis congue felis, id ultrices neque. Curabitur bibendum elit ac fermentum gravida.</p>
      <p>In eu ipsum mauris. Cras ornare tincidunt elementum. Cras nec viverra velit, et dignissim mi. Pellentesque nec rutrum justo, eu suscipit neque. Vivamus et pretium magna. Sed vitae libero cursus, consectetur erat sed, bibendum diam. In aliquet blandit gravida. Maecenas elementum mattis ornare. Duis vestibulum ex nibh, vitae ullamcorper mi euismod eget. Vivamus eget nisl quis leo interdum mollis. Nulla facilisi. Mauris in rhoncus tellus, eu iaculis libero. Etiam turpis sem, suscipit sit amet urna nec, ullamcorper pharetra lacus. Donec bibendum vitae risus eget placerat. Vivamus porta tincidunt purus, quis dictum dolor tempor non. Donec et lorem sit amet purus accumsan egestas eu vel enim.</p>
      <p>Curabitur imperdiet arcu eget tellus feugiat, ac suscipit tortor viverra. Cras bibendum nunc sed sem sagittis, non luctus tortor maximus. Aenean bibendum fermentum maximus. In vehicula mauris in ultrices volutpat. Mauris in nibh nec nisl consequat tristique sit amet congue est. In placerat varius mattis. Duis sit amet velit non nisl condimentum mollis. Etiam eget nisl turpis. Etiam tincidunt neque tristique quam euismod sollicitudin.</p>
      <p>Fusce sed eros eu ante dignissim euismod. Fusce commodo cursus libero a hendrerit. Aliquam sit amet ornare magna. Mauris justo tellus, ultricies at tristique ut, varius at eros. Proin a velit tempor eros rutrum congue in auctor magna. Integer vitae varius lectus, commodo posuere leo. Fusce malesuada velit sed metus suscipit iaculis. Etiam quis ligula leo. Donec sagittis lorem in eros rutrum varius vel nec mauris. Proin sagittis congue felis vitae efficitur. In eget metus vel libero aliquam dignissim. Nulla facilisi.</p>
      <p>Nulla et mi sed augue blandit vehicula. Mauris at velit vitae eros tristique vulputate. Vivamus id hendrerit urna. Morbi non magna vel tortor lobortis imperdiet. In semper aliquet dictum. Proin in arcu mollis, convallis nisi sed, ornare metus. Praesent et porttitor orci. Fusce luctus dignissim sem vitae vehicula. Praesent cursus orci interdum dignissim ultrices.</p>
      <p>Vestibulum non euismod nisi. Etiam pretium libero eget nulla posuere imperdiet. Aenean aliquam urna id metus ullamcorper rhoncus. Vivamus tellus diam, suscipit id nisi a, laoreet volutpat mauris. Interdum et malesuada fames ac ante ipsum primis in faucibus. Donec consectetur eros in odio posuere egestas. Nulla maximus nisl bibendum libero ultrices, vitae pulvinar ex consectetur. In at massa nec diam elementum sollicitudin. Praesent dapibus risus mi, quis fermentum tellus eleifend eget. Donec dictum, ante vitae feugiat aliquam, nisi est tincidunt elit, eu tristique elit odio non neque. Duis sed vulputate neque, sed convallis massa. Nulla facilisi. Duis hendrerit varius euismod. Suspendisse nisl tellus, ullamcorper ut risus ac, eleifend molestie nunc. Phasellus vulputate auctor urna, ut sollicitudin dui laoreet ut.</p>
      <p>Sed rutrum ligula sapien, a molestie dolor malesuada nec. Nunc aliquam, massa non semper tempus, magna dui porta massa, at maximus massa eros ac justo. Sed efficitur ac erat sed semper. Nulla placerat varius malesuada. Mauris venenatis sapien in augue rutrum, vitae semper lorem pulvinar. Nulla facilisi. Sed eget iaculis mauris. Nam euismod mattis lectus, at porttitor ante eleifend nec. Quisque maximus congue maximus. Etiam a tempus odio. Nullam neque risus, consectetur vitae lobortis a, cursus ac ipsum. Nunc posuere ultrices quam accumsan laoreet.</p>
    </Grid>
  </>);
}

export default App;
