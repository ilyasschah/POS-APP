using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.BarcodesCommands.Add;
using Products.Api.Commands.BarcodesCommands.Delete;
using Products.Api.Commands.BarcodesCommands.Update;
using Products.Api.Models;
using Products.Api.Queries.BarCodesQuery.Get;

namespace Products.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class BarcodesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<BarcodeDto>>> GetAllBarCodeProductName()
        {
            return Ok(await mediator.Send(new GetAllBarCodeProductNameQuery()));

        }
        // GET: api/barcodes/id
        [HttpGet("[action]")]
        public async Task<ActionResult<BarcodeDto>> GetById(int id)
        {
            return Ok(await mediator.Send(new GetBarcodeByIdQuery(id)));
        }
        //POST: api/barcodes
        [HttpPost("[action]")]
        public async Task<ActionResult<BarcodeDto>> Add([FromQuery] CreateBarcodeRequest createrequest)
        {
            return Ok(await mediator.Send(new AddBarcodecommand(createrequest)));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult> Update([FromQuery] UpdateBarcodeByIdRequest updaterequest)
        {
            return Ok(await mediator.Send(new UpdateBarcodecommand(updaterequest)));
        }

        [HttpDelete("Delete/{id}")]
        public async Task<ActionResult> Delete([FromQuery] int id)
        {
            return Ok(await mediator.Send(new DeleteBarcodeByIdCommand(id)));
        }
    }
}
