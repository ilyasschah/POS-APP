using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Services;
using Api.Models;

namespace Api.Commands.Promotion.Add
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