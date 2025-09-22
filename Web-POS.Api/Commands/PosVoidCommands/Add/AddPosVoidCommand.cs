using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.PosVoidCommands.Add
{
    public class AddPosVoidCommand : IRequest<bool>
    {
        public CreatePosVoidRequest Request { get; set; }
        public AddPosVoidCommand(CreatePosVoidRequest createposvoidRequest)
        {
            Request = createposvoidRequest;
        }
        public class AddPosVoidCommandHandler : IRequestHandler<AddPosVoidCommand, bool>
        {
            private readonly PosVoidService _service;

            public AddPosVoidCommandHandler(PosVoidService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(AddPosVoidCommand command, CancellationToken cancellationToken)
            {
                try
                {
                    return await _service.Create(
                         command.Request.OrderNumber,
                         command.Request.UserId ,
                         command.Request.UserName ,
                         command.Request.ProductId,
                         command.Request.ProductName,
                         command.Request.RoundNumber,
                         command.Request.Quantity,
                         command.Request.Price,
                         command.Request.Discount,
                         command.Request.DiscountType,
                         command.Request.Total,
                         command.Request.Bundle   
                        );
                }
                catch (Exception)
                {
                    throw;
                }
            }
        }

        // Nested Validator
        public class AddPosVoidCommandValidator : AbstractValidator<AddPosVoidCommand>
        {
            public AddPosVoidCommandValidator()
            {
                RuleFor(c => c.Request.OrderNumber).NotEmpty();
                RuleFor(c => c.Request.UserName).NotEmpty();
                RuleFor(c => c.Request.ProductName).NotEmpty();
                RuleFor(c => c.Request.Quantity).GreaterThan(0);
                RuleFor(c => c.Request.Price).GreaterThanOrEqualTo(0);
                RuleFor(c => c.Request.Total).GreaterThanOrEqualTo(0);
            }
        }
    }
}
