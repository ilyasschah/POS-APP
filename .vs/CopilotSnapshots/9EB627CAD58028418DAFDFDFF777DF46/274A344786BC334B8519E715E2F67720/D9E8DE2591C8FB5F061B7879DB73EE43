using Products.Api.Commands.PaymentTypeCommands.Add;
using Products.Api.Commands.PaymentTypeCommands.Delete;
using Products.Api.Commands.PaymentTypeCommands.Update;
using Products.Api.Queries.PaymentTypeQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Models;

namespace Products.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PaymentTypesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PaymentTypeDto>>> GetAll()
        {
            return Ok(await mediator.Send(new GetAllPaymentTypesQuery()));
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<PaymentTypeDto>> GetById(int id)
        {
            return Ok(await mediator.Send(new GetPaymentTypeByIdQuery { Id = id }));
        }

        [HttpGet("[action]/{name}")]
        public async Task<ActionResult<PaymentTypeDto>> GetByName(string name)
        {
            return Ok(await mediator.Send(new GetPaymentTypeByNameQuery { Name = name }));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<PaymentTypeDto>> Add([FromQuery] CreatePaymentTypeRequest req)
        {
            return Ok(await mediator.Send(new AddPaymentTypeCommand(req)));
        }

        [HttpPost("[action]/{id}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdatePaymentTypeRequest req)
        {
            return Ok(await mediator.Send(new UpdatePaymentTypeCommand(id, req)));
        }

        //DELETE: api/paymenttypes/delete/5
        [HttpDelete("[action]/{id}")]
        public async Task<bool> Delete(int id)
        {
            var result = await mediator.Send(new DeletePaymentTypeCommand(id));

            return true ;
        }
    }
}