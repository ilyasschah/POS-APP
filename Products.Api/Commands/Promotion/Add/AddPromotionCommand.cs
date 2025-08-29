using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.PromotionCommands.Add
{
    public class AddPromotionCommand : IRequest<PromotionDto>
    {
        public CreatePromotionRequest Request { get; }

        public AddPromotionCommand(CreatePromotionRequest request)
        {
            Request = request;
        }

        public class AddPromotionCommandHandler : IRequestHandler<AddPromotionCommand, PromotionDto>
        {
            private readonly PromotionService _service;

            public AddPromotionCommandHandler(PromotionService service)
            {
                _service = service;
            }

            public async Task<PromotionDto> Handle(AddPromotionCommand command, CancellationToken cancellationToken)
            {
                var newEntity = await _service.Create(command.Request);
                return MapperPromotion.MapToPromotionDto(newEntity);
            }
        }

        public class AddPromotionCommandValidator : AbstractValidator<AddPromotionCommand>
        {
            public AddPromotionCommandValidator()
            {
                RuleFor(c => c.Request.Name).NotEmpty();
            }
        }
    }
}